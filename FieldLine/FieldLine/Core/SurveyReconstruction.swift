import Foundation

enum ReconstructionFeature: String, Sendable {
    case boundary, halfway, penaltyArea, goalArea, buildOut, penaltySpot
}

enum ReconstructionSource: String, Sendable {
    case measuredEndpoints = "measured_endpoints"
    case inferred = "inferred"
    case mirrored = "mirrored"
}

struct ReconstructedLine: Identifiable, Sendable {
    var id: String
    var from: Coordinate
    var to: Coordinate
    var feature: ReconstructionFeature
    var source: ReconstructionSource
    var meters: Double { Geo.distanceMeters(from, to) }
}

struct ReconstructedMark: Identifiable, Sendable {
    var id: String
    var coordinate: Coordinate
    var feature: ReconstructionFeature
    var source: ReconstructionSource
}

struct SurveyReconstruction: Sendable {
    var inference: FieldSurveyInference
    var lines: [ReconstructedLine]
    var marks: [ReconstructedMark]

    /// Carry surveyed interior dimensions into a saved field. Unrecognized marks
    /// retain the chosen template's dimensions instead of inventing measurements.
    func applyingSurveyDimensions(to template: TemplateSpec) -> TemplateSpec {
        var spec = template
        spec.length = inference.lengthMeters
        spec.width = inference.widthMeters

        if let front = lines.first(where: { $0.id == "penaltyArea-front-fitted" }),
           let side = lines.first(where: { $0.id == "penaltyArea-left-inferred" }),
           front.meters > 0, front.meters < spec.width,
           side.meters > 0, side.meters < spec.length / 2 {
            spec.penaltyWidth = front.meters
            spec.penaltyDepth = side.meters
        }
        if template.buildOutLines == true {
            spec.goalWidth = nil
            spec.goalDepth = nil
        } else if let front = lines.first(where: { $0.id == "goalArea-front-fitted" }),
                  let side = lines.first(where: { $0.id == "goalArea-left-inferred" }),
                  front.meters > 0, front.meters < spec.penaltyWidth,
                  side.meters > 0, side.meters < spec.penaltyDepth {
            spec.goalWidth = front.meters
            spec.goalDepth = side.meters
        }

        if let spot = marks.first(where: { $0.id == "penalty-spot-centered" }),
           let nearGoalLine = lines.first(where: { $0.id == "boundary-0" }),
           let farGoalLine = lines.first(where: { $0.id == "boundary-2" }) {
            let origin = nearGoalLine.from
            let baseline = Geo.local(nearGoalLine.to, origin: origin)
            let farA = Geo.local(farGoalLine.from, origin: origin)
            let farB = Geo.local(farGoalLine.to, origin: origin)
            let mark = Geo.local(spot.coordinate, origin: origin)
            let axis = Point(x: (farA.x + farB.x - baseline.x) / 2,
                             y: (farA.y + farB.y - baseline.y) / 2)
            let axisLength = axis.magnitude
            if axisLength > 0 {
                let offset = Point(x: mark.x - baseline.x / 2,
                                   y: mark.y - baseline.y / 2)
                let depth = (offset.x * axis.x + offset.y * axis.y) / axisLength
                if depth > 0, depth < spec.penaltyDepth, depth < spec.length / 2 {
                    spec.penaltySpot = depth
                }
            }
        }
        return spec
    }

    /// Reconstructs a rectangular field from unordered GPS fixes. Derived positions are
    /// explicitly tagged so they cannot be confused with physical measurements.
    static func build(from records: [GPSPointRecord], templateID: String? = nil) -> Self? {
        guard var inference = SurveyInference.suggest(for: records), let first = records.first else { return nil }
        if templateID == "7v7" {
            for id in inference.goalFrontPointIDs { inference.assignments.removeValue(forKey: id) }
            inference.goalFrontPointIDs = []
        }
        let coordinateByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.coordinate) })
        let origin = first.coordinate
        let localByID = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, Geo.local($0.coordinate, origin: origin))
        })
        let ids = inference.cornerPointIDs
        guard ids.count == 4,
              let a = localByID[ids[0]], let b = localByID[ids[1]],
              let c = localByID[ids[2]], let d = localByID[ids[3]] else { return nil }

        // Bilinear interpolation exactly preserves the four measured corners.
        func location(_ u: Double, _ v: Double) -> Coordinate {
            let x = a.x * (1-u) * (1-v) + b.x * u * (1-v) + c.x * u * v + d.x * (1-u) * v
            let y = a.y * (1-u) * (1-v) + b.y * u * (1-v) + c.y * u * v + d.y * (1-u) * v
            return Geo.destinationCoordinate(origin, bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y))
        }
        func uv(_ id: UUID) -> (u: Double, v: Double)? {
            guard let point = localByID[id] else { return nil }
            let width = b - a, length = d - a, offset = point - a
            let determinant = width.x * length.y - width.y * length.x
            guard abs(determinant) > 0.001 else { return nil }
            return ((offset.x * length.y - offset.y * length.x) / determinant,
                    (width.x * offset.y - width.y * offset.x) / determinant)
        }

        var lines: [ReconstructedLine] = []
        var marks: [ReconstructedMark] = []
        for i in 0..<4 {
            guard let from = coordinateByID[ids[i]], let to = coordinateByID[ids[(i + 1) % 4]] else { continue }
            lines.append(.init(id: "boundary-\(i)", from: from, to: to,
                               feature: .boundary, source: .measuredEndpoints))
        }
        lines.append(.init(id: "halfway", from: location(0, 0.5), to: location(1, 0.5),
                           feature: .halfway, source: .inferred))

        func addArea(_ ids: [UUID], feature: ReconstructionFeature) {
            guard ids.count == 2,
                  let leftUV = uv(ids[0]), let rightUV = uv(ids[1]) else { return }
            let prefix = feature.rawValue
            // The raw points are retained separately. Fitted markings use the measured width
            // and mean depth but are centered on the field axis, suppressing GPS asymmetry.
            let halfWidth = abs(rightUV.u - leftUV.u) / 2
            let depth = (leftUV.v + rightUV.v) / 2
            let leftU = 0.5 - halfWidth, rightU = 0.5 + halfWidth
            let left = location(leftU, depth), right = location(rightU, depth)
            lines.append(.init(id: "\(prefix)-front-fitted", from: left, to: right,
                               feature: feature, source: .inferred))
            lines.append(.init(id: "\(prefix)-left-inferred", from: location(leftU, 0), to: left,
                               feature: feature, source: .inferred))
            lines.append(.init(id: "\(prefix)-right-inferred", from: right, to: location(rightU, 0),
                               feature: feature, source: .inferred))
            let mirroredLeft = location(leftU, 1 - depth)
            let mirroredRight = location(rightU, 1 - depth)
            lines.append(.init(id: "\(prefix)-left-mirrored", from: location(leftU, 1), to: mirroredLeft,
                               feature: feature, source: .mirrored))
            lines.append(.init(id: "\(prefix)-front-mirrored", from: mirroredLeft, to: mirroredRight,
                               feature: feature, source: .mirrored))
            lines.append(.init(id: "\(prefix)-right-mirrored", from: mirroredRight, to: location(rightU, 1),
                               feature: feature, source: .mirrored))
        }
        addArea(inference.penaltyFrontPointIDs, feature: .penaltyArea)
        addArea(inference.goalFrontPointIDs, feature: .goalArea)
        if templateID == "7v7", inference.penaltyFrontPointIDs.count == 2,
           let firstPA = uv(inference.penaltyFrontPointIDs[0]),
           let secondPA = uv(inference.penaltyFrontPointIDs[1]) {
            let penaltyDepth = (firstPA.v + secondPA.v) / 2
            let buildOutDepth = (penaltyDepth + 0.5) / 2
            lines.append(.init(id: "build-out-near", from: location(0, buildOutDepth),
                               to: location(1, buildOutDepth), feature: .buildOut, source: .inferred))
            lines.append(.init(id: "build-out-mirrored", from: location(0, 1 - buildOutDepth),
                               to: location(1, 1 - buildOutDepth), feature: .buildOut, source: .mirrored))
        }
        if let spotID = inference.penaltySpotPointID,
           let position = uv(spotID) {
            marks.append(.init(id: "penalty-spot-centered", coordinate: location(0.5, position.v),
                               feature: .penaltySpot, source: .inferred))
            marks.append(.init(id: "penalty-spot-mirrored", coordinate: location(0.5, 1-position.v),
                               feature: .penaltySpot, source: .mirrored))
        }
        return .init(inference: inference, lines: lines, marks: marks)
    }

    var csv: String {
        var rows = ["item_id,geometry,feature,source,from_latitude,from_longitude,to_latitude,to_longitude,distance_m"]
        for line in lines {
            rows.append("\(line.id),line,\(line.feature.rawValue),\(line.source.rawValue),\(line.from.latitude),\(line.from.longitude),\(line.to.latitude),\(line.to.longitude),\(line.meters)")
        }
        for mark in marks {
            rows.append("\(mark.id),point,\(mark.feature.rawValue),\(mark.source.rawValue),\(mark.coordinate.latitude),\(mark.coordinate.longitude),,,")
        }
        return rows.joined(separator: "\n") + "\n"
    }
}
