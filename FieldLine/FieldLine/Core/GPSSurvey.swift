import Foundation

struct GPSFixRecord: Codable, Sendable {
    var coordinate: Coordinate
    var recordedAt: Date
    var horizontalAccuracyMeters: Double
    var usedInAverage: Bool
}

/// A saved point: either a legacy single fix or a stationary aggregate with raw fixes.
struct GPSPointRecord: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var coordinate: Coordinate
    var recordedAt: Date
    var horizontalAccuracyMeters: Double
    var altitudeMeters: Double?
    var verticalAccuracyMeters: Double?
    var speedMetersPerSecond: Double?
    var courseDegrees: Double?
    /// Optional field node, such as A, HL1, or PA-TOP-2. GPS points remain valid without one.
    var fieldNodeID: String?
    /// Present for three-second stationary captures. Legacy single-fix points keep these nil.
    var samplingDurationSeconds: Double? = nil
    var samplingSpreadMeters: Double? = nil
    var rawFixes: [GPSFixRecord]? = nil
}

/// A surveyed line is explicit; the order in which its endpoints were recorded is irrelevant.
struct GPSSegment: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var fromPointID: UUID
    var toPointID: UUID
}

struct GPSSurveyLine: Identifiable, Sendable {
    var id: String
    var fromPointID: UUID
    var toPointID: UUID
    var isAutomatic: Bool
    var manualSegmentID: UUID?
}

struct GPSSurvey: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var points: [GPSPointRecord] = []
    var segments: [GPSSegment] = []
    var templateID: String?

    private enum CodingKeys: String, CodingKey { case id, name, createdAt, points, segments, templateID }

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), points: [GPSPointRecord] = [],
         segments: [GPSSegment] = [], templateID: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.points = points
        self.segments = segments
        self.templateID = templateID
    }

    /// Older saved surveys did not have lines. Keep their GPS points without inventing connections.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        points = try values.decode([GPSPointRecord].self, forKey: .points)
        segments = try values.decodeIfPresent([GPSSegment].self, forKey: .segments) ?? []
        templateID = try values.decodeIfPresent(String.self, forKey: .templateID)
    }

    func pointNumber(for id: UUID) -> Int? {
        points.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    func distanceMeters(from startID: UUID, to endID: UUID) -> Double? {
        guard let start = points.first(where: { $0.id == startID }),
              let end = points.first(where: { $0.id == endID }) else { return nil }
        return Geo.distanceMeters(start.coordinate, end.coordinate)
    }

    func distanceMeters(for segment: GPSSegment) -> Double? {
        distanceMeters(from: segment.fromPointID, to: segment.toPointID)
    }

    var totalSegmentDistanceMeters: Double {
        segments.compactMap { distanceMeters(for: $0) }.reduce(0, +)
    }

    /// The field template supplies legal topology. Capture order never supplies edges.
    func lines(using geometry: FieldGeometry?) -> [GPSSurveyLine] {
        var result: [GPSSurveyLine] = []
        if let geometry {
            let byNode = Dictionary(points.compactMap { point -> (String, UUID)? in
                guard let node = point.fieldNodeID else { return nil }
                return (node, point.id)
            }, uniquingKeysWith: { first, _ in first })
            // Split each sideline/goal line at any recorded node on that boundary. This keeps
            // halfway and build-out points on the outline, regardless of when they were sampled.
            let boundaryIDs: Set<String> = ["AB", "BC", "CD", "DA"]
            for edge in geometry.segments where boundaryIDs.contains(edge.id) {
                let start = geometry.point(edge.from), end = geometry.point(edge.to)
                let dx = end.x - start.x, dy = end.y - start.y
                let squaredLength = dx * dx + dy * dy
                let boundaryNodes = geometry.nodes.compactMap { node -> (id: String, fraction: Double)? in
                    guard byNode[node.id] != nil else { return nil }
                    let px = node.point.x - start.x, py = node.point.y - start.y
                    let fraction = (px * dx + py * dy) / squaredLength
                    guard abs(px * dy - py * dx) < 0.0001,
                          fraction >= -0.000001, fraction <= 1.000001 else { return nil }
                    return (node.id, fraction)
                }.sorted { $0.fraction < $1.fraction }
                for pair in zip(boundaryNodes, boundaryNodes.dropFirst()) {
                    guard let from = byNode[pair.0.id], let to = byNode[pair.1.id] else { continue }
                    result.append(.init(id: "auto-\(edge.id)-\(pair.0.id)-\(pair.1.id)", fromPointID: from,
                                        toPointID: to, isAutomatic: true, manualSegmentID: nil))
                }
            }
            for segment in geometry.segments where !boundaryIDs.contains(segment.id) {
                guard let from = byNode[segment.from], let to = byNode[segment.to], from != to else { continue }
                result.append(.init(id: "auto-\(segment.id)", fromPointID: from, toPointID: to,
                                    isAutomatic: true, manualSegmentID: nil))
            }
        }
        for segment in segments where !result.contains(where: {
            ($0.fromPointID == segment.fromPointID && $0.toPointID == segment.toPointID) ||
            ($0.fromPointID == segment.toPointID && $0.toPointID == segment.fromPointID)
        }) {
            result.append(.init(id: "manual-\(segment.id.uuidString)", fromPointID: segment.fromPointID,
                                toPointID: segment.toPointID, isAutomatic: false, manualSegmentID: segment.id))
        }
        return result
    }

    func totalLineDistanceMeters(using geometry: FieldGeometry?) -> Double {
        lines(using: geometry).compactMap { distanceMeters(from: $0.fromPointID, to: $0.toPointID) }.reduce(0, +)
    }

    @discardableResult mutating func assign(_ nodeID: String?, to pointID: UUID, using geometry: FieldGeometry) -> Bool {
        guard let index = points.firstIndex(where: { $0.id == pointID }),
              nodeID == nil || geometry.nodes.contains(where: { $0.id == nodeID }),
              nodeID == nil || !points.contains(where: { $0.id != pointID && $0.fieldNodeID == nodeID }) else { return false }
        points[index].fieldNodeID = nodeID
        return true
    }

    func hasSegment(between first: UUID, and second: UUID) -> Bool {
        segments.contains {
            ($0.fromPointID == first && $0.toPointID == second) ||
            ($0.fromPointID == second && $0.toPointID == first)
        }
    }

    @discardableResult mutating func addSegment(from first: UUID, to second: UUID) -> Bool {
        guard first != second, distanceMeters(from: first, to: second) != nil,
              !hasSegment(between: first, and: second) else { return false }
        segments.append(GPSSegment(fromPointID: first, toPointID: second))
        return true
    }

    /// Point export preserves WGS84 coordinates without assuming that capture order is a path.
    var csv: String {
        var lines = ["index,point_id,field_node_id,recorded_at_utc,latitude,longitude,horizontal_accuracy_m,altitude_m,vertical_accuracy_m,speed_m_s,course_deg,sampling_duration_s,accepted_fix_count,sampling_spread_m"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for (index, point) in points.enumerated() {
            let fields: [String] = [
                String(index + 1), point.id.uuidString, point.fieldNodeID ?? "", formatter.string(from: point.recordedAt),
                String(point.coordinate.latitude), String(point.coordinate.longitude),
                String(point.horizontalAccuracyMeters),
                point.altitudeMeters.map { String($0) } ?? "",
                point.verticalAccuracyMeters.map { String($0) } ?? "",
                point.speedMetersPerSecond.map { String($0) } ?? "",
                point.courseDegrees.map { String($0) } ?? "",
                point.samplingDurationSeconds.map { String($0) } ?? "",
                point.rawFixes.map { String($0.filter(\.usedInAverage).count) } ?? "",
                point.samplingSpreadMeters.map { String($0) } ?? ""
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    var rawFixesCSV: String {
        var rows = ["point_index,point_id,fix_index,recorded_at_utc,latitude,longitude,horizontal_accuracy_m,used_in_average"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for (pointIndex, point) in points.enumerated() {
            for (fixIndex, fix) in (point.rawFixes ?? []).enumerated() {
                rows.append("\(pointIndex + 1),\(point.id.uuidString),\(fixIndex + 1),\(formatter.string(from: fix.recordedAt)),\(fix.coordinate.latitude),\(fix.coordinate.longitude),\(fix.horizontalAccuracyMeters),\(fix.usedInAverage)")
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    func linesCSV(using geometry: FieldGeometry?) -> String {
        var rows = ["line_index,source,from_point_index,to_point_index,from_point_id,to_point_id,distance_m"]
        for (index, line) in lines(using: geometry).enumerated() {
            guard let from = pointNumber(for: line.fromPointID),
                  let to = pointNumber(for: line.toPointID),
                  let distance = distanceMeters(from: line.fromPointID, to: line.toPointID) else { continue }
            rows.append("\(index + 1),\(line.isAutomatic ? "field" : "manual"),\(from),\(to),\(line.fromPointID.uuidString),\(line.toPointID.uuidString),\(distance)")
        }
        return rows.joined(separator: "\n") + "\n"
    }
}
