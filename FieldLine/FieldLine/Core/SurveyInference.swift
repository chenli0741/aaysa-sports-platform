import Foundation

/// A reviewable suggestion. It never changes the recorded coordinates or capture order.
struct FieldSurveyInference: Sendable {
    var assignments: [UUID: String]
    var cornerPointIDs: [UUID]
    var penaltyFrontPointIDs: [UUID]
    var goalFrontPointIDs: [UUID]
    var buildOutLinePointIDs: [[UUID]]
    var penaltySpotPointID: UUID?
    var lengthMeters: Double
    var widthMeters: Double
}

enum SurveyInference {
    private struct Sample {
        let id: UUID
        let position: Point
    }

    static func suggest(for records: [GPSPointRecord]) -> FieldSurveyInference? {
        guard records.count >= 4, let first = records.first else { return nil }
        let samples = records.map { Sample(id: $0.id, position: Geo.local($0.coordinate, origin: first.coordinate)) }
        let hull = convexHull(samples)
        guard hull.count >= 4 else { return nil }

        var corners: [Sample] = []
        var bestArea = 0.0
        for a in 0..<(hull.count - 3) {
            for b in (a + 1)..<(hull.count - 2) {
                for c in (b + 1)..<(hull.count - 1) {
                    for d in (c + 1)..<hull.count {
                        let candidate = [hull[a], hull[b], hull[c], hull[d]]
                        let area = polygonArea(candidate)
                        if area > bestArea { bestArea = area; corners = candidate }
                    }
                }
            }
        }
        guard corners.count == 4 else { return nil }
        let sides = (0..<4).map { i in
            distance(corners[i].position, corners[(i + 1) % 4].position)
        }
        let pair0 = (sides[0] + sides[2]) / 2
        let pair1 = (sides[1] + sides[3]) / 2
        let long = max(pair0, pair1), short = min(pair0, pair1)
        guard short >= 10, long / short >= 1.12, long / short <= 3,
              abs(sides[0] - sides[2]) / pair0 < 0.35,
              abs(sides[1] - sides[3]) / pair1 < 0.35,
              isRoughRectangle(corners) else { return nil }

        let shortEdgeStarts = pair0 < pair1 ? [0, 2] : [1, 3]
        let cornerIDs = Set(corners.map(\.id))
        let interior = samples.filter { sample in
            guard !cornerIDs.contains(sample.id), inside(sample.position, corners) else { return false }
            let edgeDistance = (0..<4).map { i in
                distanceToSegment(sample.position, corners[i].position, corners[(i + 1) % 4].position)
            }.min() ?? 0
            return edgeDistance > max(4, short * 0.12)
        }

        var chosenStart = shortEdgeStarts[0]
        var penaltyPair: (Sample, Sample)?
        var bestPairScore = -Double.infinity
        if interior.count >= 2 {
            for start in shortEdgeStarts {
                let a = corners[start].position
                let b = corners[(start + 1) % 4].position
                let d = corners[(start + 3) % 4].position
                for i in 0..<(interior.count - 1) {
                    for j in (i + 1)..<interior.count {
                        guard let firstUV = normalized(interior[i].position, a: a, b: b, d: d),
                              let secondUV = normalized(interior[j].position, a: a, b: b, d: d) else { continue }
                        let widthSeparation = abs(firstUV.u - secondUV.u)
                        let depthDifference = abs(firstUV.v - secondUV.v)
                        guard (0.1...0.9).contains(firstUV.u), (0.1...0.9).contains(secondUV.u),
                              (0.08...0.38).contains(firstUV.v), (0.08...0.38).contains(secondUV.v),
                              (0.3...0.8).contains(widthSeparation), depthDifference <= 0.12 else { continue }
                        let score = widthSeparation - depthDifference * 0.5
                        guard score > bestPairScore else { continue }
                        bestPairScore = score
                        chosenStart = start
                        penaltyPair = firstUV.u < secondUV.u
                            ? (interior[i], interior[j]) : (interior[j], interior[i])
                    }
                }
            }
        }

        let ordered = (0..<4).map { corners[(chosenStart + $0) % 4] }
        var assignments = Dictionary(uniqueKeysWithValues: zip(ordered.map(\.id), ["A", "B", "C", "D"]))
        var goalPair: (Sample, Sample)?
        var spot: Sample?
        if let penaltyPair {
            assignments[penaltyPair.0.id] = "PA-TOP-2"
            assignments[penaltyPair.1.id] = "PA-TOP-3"
            let a = ordered[0].position, b = ordered[1].position, d = ordered[3].position
            guard let firstPA = normalized(penaltyPair.0.position, a: a, b: b, d: d),
                  let secondPA = normalized(penaltyPair.1.position, a: a, b: b, d: d) else { return nil }
            let penaltyDepth = (firstPA.v + secondPA.v) / 2
            let remaining = interior.filter { $0.id != penaltyPair.0.id && $0.id != penaltyPair.1.id }
            var goalScore = -Double.infinity
            if remaining.count >= 2 {
                for i in 0..<(remaining.count - 1) {
                    for j in (i + 1)..<remaining.count {
                        guard let left = normalized(remaining[i].position, a: a, b: b, d: d),
                              let right = normalized(remaining[j].position, a: a, b: b, d: d) else { continue }
                        let separation = abs(left.u - right.u)
                        let meanDepth = (left.v + right.v) / 2
                        guard (0.25...0.75).contains(left.u), (0.25...0.75).contains(right.u),
                              (0.10...0.38).contains(separation),
                              meanDepth >= 0.04, meanDepth < penaltyDepth - 0.04,
                              abs(left.v - right.v) < 0.08 else { continue }
                        let score = separation - abs(left.v - right.v)
                        guard score > goalScore else { continue }
                        goalScore = score
                        goalPair = left.u < right.u
                            ? (remaining[i], remaining[j]) : (remaining[j], remaining[i])
                    }
                }
            }
            if let goalPair {
                assignments[goalPair.0.id] = "GA-TOP-2"
                assignments[goalPair.1.id] = "GA-TOP-3"
            }
            spot = remaining.filter { $0.id != goalPair?.0.id && $0.id != goalPair?.1.id }
                .compactMap { candidate -> (Sample, Double)? in
                    guard let uv = normalized(candidate.position, a: a, b: b, d: d),
                          abs(uv.u - 0.5) <= 0.15,
                          abs(uv.v - penaltyDepth) <= 0.09 else { return nil }
                    return (candidate, abs(uv.u - 0.5) + abs(uv.v - penaltyDepth))
                }
                .min { $0.1 < $1.1 }?.0
            if let spot { assignments[spot.id] = "SPOT-TOP" }
        }
        let reserved = Set(assignments.keys)
        let a = ordered[0].position, b = ordered[1].position, d = ordered[3].position
        let possibleBuildOut = samples.filter { !reserved.contains($0.id) }.compactMap { sample -> (Sample, u: Double, v: Double)? in
            guard let uv = normalized(sample.position, a: a, b: b, d: d),
                  (-0.08...1.08).contains(uv.u), (0.15...0.85).contains(uv.v),
                  abs(uv.v - 0.5) >= 0.08 else { return nil }
            return (sample, uv.u, uv.v)
        }
        var buildOutCandidates: [(ids: [UUID], depth: Double, score: Double)] = []
        if possibleBuildOut.count >= 2 {
            for i in 0..<(possibleBuildOut.count-1) {
                for j in (i+1)..<possibleBuildOut.count {
                    let first = possibleBuildOut[i], second = possibleBuildOut[j]
                    let separation = abs(first.u-second.u), depthDifference = abs(first.v-second.v)
                    guard separation >= 0.72, depthDifference <= 0.07 else { continue }
                    buildOutCandidates.append(([first.0.id,second.0.id],(first.v+second.v)/2,separation-depthDifference))
                }
            }
        }
        var buildOutLines: [[UUID]] = []
        var used: Set<UUID> = []
        for candidate in buildOutCandidates.sorted(by: { $0.score > $1.score }) where candidate.ids.allSatisfy({ !used.contains($0) }) {
            buildOutLines.append(candidate.ids); used.formUnion(candidate.ids)
            if buildOutLines.count == 2 { break }
        }
        if buildOutLines.count == 2 {
            let depths = buildOutLines.compactMap { ids in
                possibleBuildOut.first(where: { $0.0.id == ids[0] }).map(\.v)
            }
            if depths.count != 2 || abs((depths[0]+depths[1])-1) > 0.18 { buildOutLines = [] }
        }
        return .init(assignments: assignments, cornerPointIDs: ordered.map(\.id),
                     penaltyFrontPointIDs: penaltyPair.map { [$0.0.id, $0.1.id] } ?? [],
                     goalFrontPointIDs: goalPair.map { [$0.0.id, $0.1.id] } ?? [],
                     buildOutLinePointIDs: buildOutLines,
                     penaltySpotPointID: spot?.id,
                     lengthMeters: long, widthMeters: short)
    }

    private static func convexHull(_ samples: [Sample]) -> [Sample] {
        let sorted = samples.sorted {
            $0.position.x == $1.position.x ? $0.position.y < $1.position.y : $0.position.x < $1.position.x
        }
        var lower: [Sample] = [], upper: [Sample] = []
        for sample in sorted {
            while lower.count >= 2 && turn(lower[lower.count - 2], lower[lower.count - 1], sample) <= 0 {
                lower.removeLast()
            }
            lower.append(sample)
        }
        for sample in sorted.reversed() {
            while upper.count >= 2 && turn(upper[upper.count - 2], upper[upper.count - 1], sample) <= 0 {
                upper.removeLast()
            }
            upper.append(sample)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    private static func turn(_ a: Sample, _ b: Sample, _ c: Sample) -> Double {
        let ab = b.position - a.position, ac = c.position - a.position
        return ab.x * ac.y - ab.y * ac.x
    }

    private static func polygonArea(_ samples: [Sample]) -> Double {
        abs((0..<samples.count).reduce(0.0) { total, i in
            let a = samples[i].position, b = samples[(i + 1) % samples.count].position
            return total + a.x * b.y - a.y * b.x
        }) / 2
    }

    private static func isRoughRectangle(_ corners: [Sample]) -> Bool {
        (0..<4).allSatisfy { i in
            let current = corners[i].position
            let before = corners[(i + 3) % 4].position - current
            let after = corners[(i + 1) % 4].position - current
            return abs(before.x * after.x + before.y * after.y) / (before.magnitude * after.magnitude) < 0.4
        }
    }

    private static func distance(_ a: Point, _ b: Point) -> Double { (a - b).magnitude }

    private static func distanceToSegment(_ point: Point, _ start: Point, _ end: Point) -> Double {
        let v = end - start, w = point - start
        let t = max(0, min(1, (w.x * v.x + w.y * v.y) / (v.x * v.x + v.y * v.y)))
        return hypot(w.x - t * v.x, w.y - t * v.y)
    }

    private static func inside(_ point: Point, _ corners: [Sample]) -> Bool {
        (0..<4).allSatisfy { i in
            let a = corners[i].position, b = corners[(i + 1) % 4].position
            let edge = b - a, relative = point - a
            return edge.x * relative.y - edge.y * relative.x > 0
        }
    }

    private static func normalized(_ point: Point, a: Point, b: Point, d: Point) -> (u: Double, v: Double)? {
        let x = b - a, y = d - a, delta = point - a
        let determinant = x.x * y.y - x.y * y.x
        guard abs(determinant) > 0.001 else { return nil }
        return ((delta.x * y.y - delta.y * y.x) / determinant,
                (x.x * delta.y - x.y * delta.x) / determinant)
    }
}

struct SurveyFieldClassification: Equatable, Sendable {
    var templateID: String
    var title: String
    var confidence: Double
    var reason: String
}

enum SurveyFieldClassifier {
    static func classify(_ inference: FieldSurveyInference) -> SurveyFieldClassification {
        if inference.buildOutLinePointIDs.count == 2 {
            return .init(templateID: "7v7", title: "7v7 回撤线场地", confidence: 0.96,
                         reason: "识别到两条位于禁区与中线之间、彼此对称的跨场回撤线")
        }
        if inference.goalFrontPointIDs.count == 2 {
            let id = inference.lengthMeters >= 92 || inference.widthMeters >= 62 ? "11v11" : "9v9"
            return .init(templateID: id, title: "标准场地", confidence: 0.93,
                         reason: "识别到禁区和独立球门区结构")
        }
        if inference.lengthMeters <= 70 && inference.widthMeters <= 50 {
            return .init(templateID: "7v7", title: "可能是 7v7 回撤线场地", confidence: 0.72,
                         reason: "实测外框尺寸接近 7v7；继续采集两条回撤线端点可提高置信度")
        }
        let id = inference.lengthMeters >= 92 || inference.widthMeters >= 62 ? "11v11" : "9v9"
        return .init(templateID: id, title: "可能是标准场地", confidence: 0.68,
                     reason: "实测外框尺寸更接近标准模板；继续采集球门区前角可提高置信度")
    }
}
