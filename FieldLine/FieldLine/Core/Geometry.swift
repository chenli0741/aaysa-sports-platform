import Foundation

struct Point: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    static func -(lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    var magnitude: Double { hypot(x, y) }
}
struct Coordinate: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
}
struct FieldNode: Codable, Identifiable, Sendable {
    var id: String
    var point: Point
}
struct Segment: Codable, Identifiable, Sendable {
    var id: String
    var from: String
    var to: String
}
struct FieldCircle: Codable, Identifiable, Sendable {
    var id: String
    var center: Point
    var radius: Double
    var startAngle: Double
    var endAngle: Double
}
struct TemplateSpec: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var length: Double
    var width: Double
    var penaltyDepth: Double
    var penaltyWidth: Double
    var goalDepth: Double?
    var goalWidth: Double?
    var centerRadius: Double
    var penaltySpot: Double
    var buildOutLines: Bool? = nil
    static func custom(length: Double, width: Double) -> Self {
        .init(id: "custom", name: "Custom", length: length, width: width,
              penaltyDepth: length * 0.157, penaltyWidth: width * 0.593,
              goalDepth: length * 0.0524, goalWidth: width * 0.269,
              centerRadius: min(length, width) * 0.1346, penaltySpot: length * 0.1048)
    }
}
struct FieldGeometry: Codable, Sendable {
    var spec: TemplateSpec
    var nodes: [FieldNode]
    var segments: [Segment]
    var circles: [FieldCircle]
    var generationStrategyVersion = 2
    func point(_ id: String) -> Point { nodes.first { $0.id == id }!.point }
    func connectedSegments(_ node: String) -> [Segment] { segments.filter { $0.from == node || $0.to == node } }
    static func generate(_ spec: TemplateSpec) -> Self {
        let w = spec.width, l = spec.length
        var nodes: [FieldNode] = [
            .init(id: "A", point: .init(x: 0, y: 0)), .init(id: "B", point: .init(x: w, y: 0)),
            .init(id: "C", point: .init(x: w, y: l)), .init(id: "D", point: .init(x: 0, y: l)),
            .init(id: "HL1", point: .init(x: 0, y: l/2)), .init(id: "HL2", point: .init(x: w, y: l/2)),
            .init(id: "CENTER", point: .init(x: w/2, y: l/2))]
        var segments = [Segment(id: "AB", from: "A", to: "B"), .init(id: "BC", from: "B", to: "C"),
                        .init(id: "CD", from: "C", to: "D"), .init(id: "DA", from: "D", to: "A"),
                        .init(id: "HALFWAY", from: "HL1", to: "HL2")]
        var circles = [FieldCircle(id: "CENTER-CIRCLE", center: .init(x: w/2, y: l/2), radius: spec.centerRadius, startAngle: 0, endAngle: 360)]
        for (side, baseline, sign) in [("TOP", 0.0, 1.0), ("BOTTOM", l, -1.0)] {
            var areas = [("PA", spec.penaltyWidth, spec.penaltyDepth)]
            if let goalWidth = spec.goalWidth, let goalDepth = spec.goalDepth {
                areas.append(("GA", goalWidth, goalDepth))
            }
            for (kind, width, depth) in areas {
                let prefix = "\(kind)-\(side)"
                let points = [Point(x: (w-width)/2, y: baseline), Point(x: (w-width)/2, y: baseline+sign*depth),
                              Point(x: (w+width)/2, y: baseline+sign*depth), Point(x: (w+width)/2, y: baseline)]
                for i in 0..<4 { nodes.append(.init(id: "\(prefix)-\(i+1)", point: points[i])) }
                for i in 1...3 { segments.append(.init(id: "\(prefix)-LINE-\(i)", from: "\(prefix)-\(i)", to: "\(prefix)-\(i+1)")) }
            }
            let center = Point(x: w/2, y: baseline+sign*spec.penaltySpot)
            nodes.append(.init(id: "SPOT-\(side)", point: center))
            let ratio = (spec.penaltyDepth-spec.penaltySpot)/spec.centerRadius
            if ratio >= 0 && ratio < 1 {
                let angle = asin(ratio)*180 / .pi
                circles.append(.init(id: "ARC-\(side)", center: center, radius: spec.centerRadius,
                                     startAngle: side == "TOP" ? angle : 180+angle,
                                     endAngle: side == "TOP" ? 180-angle : 360-angle))
            }
        }
        if spec.buildOutLines == true {
            // One line in each half, midway from the penalty-area front to halfway.
            let topY = (spec.penaltyDepth + l / 2) / 2
            let bottomY = l - topY
            for (side, y) in [("TOP", topY), ("BOTTOM", bottomY)] {
                let left = "BOL-\(side)-L", right = "BOL-\(side)-R"
                nodes.append(.init(id: left, point: .init(x: 0, y: y)))
                nodes.append(.init(id: right, point: .init(x: w, y: y)))
                segments.append(.init(id: "BOL-\(side)", from: left, to: right))
            }
        }
        return .init(spec: spec, nodes: nodes, segments: segments, circles: circles)
    }
}

/// Upgrade geometry saved by the original 7v7 prototype without moving its calibrated field.
func migrateSaved7v7Field(_ field: SavedField) -> SavedField {
    guard field.geometry.spec.id == "7v7", field.geometry.generationStrategyVersion < 2 else { return field }
    var updated = field
    var spec = updated.geometry.spec
    spec.goalDepth = nil
    spec.goalWidth = nil
    spec.buildOutLines = true
    updated.geometry = .generate(spec)
    if var calibration = updated.calibration {
        calibration.generatedGeoNodes = Dictionary(uniqueKeysWithValues: updated.geometry.nodes.map {
            ($0.id, calibration.coordinate($0.point, geometry: updated.geometry))
        })
        calibration.generatedGeoNodes[calibration.anchor1Node] = calibration.anchor1
        calibration.generatedGeoNodes[calibration.anchor2Node] = calibration.correctedAnchor2
        updated.calibration = calibration
    }
    return updated
}

enum Geo {
    static let earthRadius = 6_371_000.0
    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    static func signedAngle(_ angle: Double) -> Double {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        return normalized > 180 ? normalized - 360 : (normalized < -180 ? normalized + 360 : normalized)
    }
    static func distanceMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let dLat = radians(b.latitude-a.latitude), dLon = radians(b.longitude-a.longitude)
        let h = pow(sin(dLat/2), 2) + cos(radians(a.latitude))*cos(radians(b.latitude))*pow(sin(dLon/2), 2)
        return 2 * earthRadius * asin(sqrt(min(1, max(0, h))))
    }
    static func bearingDegrees(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = radians(a.latitude), lat2 = radians(b.latitude), dLon = radians(b.longitude-a.longitude)
        return (degrees(atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dLon)))+360).truncatingRemainder(dividingBy: 360)
    }
    static func destinationCoordinate(_ origin: Coordinate, bearing: Double, distance: Double) -> Coordinate {
        let lat = radians(origin.latitude), lon = radians(origin.longitude), b = radians(bearing), d = distance/earthRadius
        let newLat = asin(sin(lat)*cos(d)+cos(lat)*sin(d)*cos(b))
        let newLon = lon + atan2(sin(b)*sin(d)*cos(lat), cos(d)-sin(lat)*sin(newLat))
        return .init(latitude: degrees(newLat), longitude: (degrees(newLon)+540).truncatingRemainder(dividingBy: 360)-180)
    }
    // Local tangent coordinates: x east, y north. Suitable for a single football field.
    static func local(_ point: Coordinate, origin: Coordinate) -> Point {
        let d = distanceMeters(origin, point), b = radians(bearingDegrees(origin, point))
        return .init(x: d*sin(b), y: d*cos(b))
    }
    static func project(_ position: Coordinate, start: Coordinate, end: Coordinate) -> (cross: Double, along: Double, length: Double) {
        let p = local(position, origin: start), v = local(end, origin: start), length = v.magnitude
        guard length > 0.001 else { return (0, 0, 0) }
        // Positive cross-track is right of travel; negative is left.
        return ((p.x*v.y-p.y*v.x)/length, (p.x*v.x+p.y*v.y)/length, length)
    }
}
struct Calibration: Codable, Sendable {
    var anchor1Node: String
    var anchor1: Coordinate
    var anchor2Node: String
    var candidate: Coordinate
    var correctedAnchor2: Coordinate
    var fieldBearing: Double
    var accuracy: Double
    var calibratedAt: Date
    var generatedGeoNodes: [String: Coordinate]
    var secondPointIsDirectionOnly: Bool? = nil
    /// Uniform factor selected when the measured second corner is authoritative.
    /// The complete standard template is scaled around anchor 1 to meet that point.
    var measuredScale: Double? = nil
    /// New calibrations preserve all four measured field corners. Template nodes are
    /// fitted into this quadrilateral instead of extending a measured edge to the
    /// template's nominal dimensions. Nil keeps older two-anchor saves compatible.
    var measuredCorners: [String: Coordinate]? = nil
    var usesMeasuredBoundary: Bool {
        guard let measuredCorners else { return false }
        return ["A", "B", "C", "D"].allSatisfy { measuredCorners[$0] != nil }
    }
    var usesMeasuredScale: Bool { measuredScale != nil }
    func coordinate(_ point: Point, geometry: FieldGeometry) -> Coordinate {
        if let measuredCorners,
           let a = measuredCorners["A"], let b = measuredCorners["B"],
           let c = measuredCorners["C"], let d = measuredCorners["D"],
           geometry.spec.width > 0, geometry.spec.length > 0 {
            let u = point.x / geometry.spec.width
            let v = point.y / geometry.spec.length
            let bl = Geo.local(b, origin: a), cl = Geo.local(c, origin: a), dl = Geo.local(d, origin: a)
            let x = bl.x * u * (1-v) + cl.x * u * v + dl.x * (1-u) * v
            let y = bl.y * u * (1-v) + cl.y * u * v + dl.y * (1-u) * v
            return Geo.destinationCoordinate(a, bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y))
        }
        let delta = point - geometry.point(anchor1Node)
        let scale = measuredScale ?? 1
        return Geo.destinationCoordinate(anchor1, bearing: fieldBearing + Geo.degrees(atan2(delta.y, delta.x)), distance: delta.magnitude * scale)
    }
    func fieldPosition(of coordinate: Coordinate, geometry: FieldGeometry) -> Point {
        if let measuredCorners,
           let a = measuredCorners["A"], let b = measuredCorners["B"],
           let c = measuredCorners["C"], let d = measuredCorners["D"],
           geometry.spec.width > 0, geometry.spec.length > 0 {
            let target = Geo.local(coordinate, origin: a)
            let av = Point(x: 0, y: 0), bv = Geo.local(b, origin: a)
            let cv = Geo.local(c, origin: a), dv = Geo.local(d, origin: a)
            let determinant = bv.x * dv.y - bv.y * dv.x
            var u = abs(determinant) > 0.001 ? (target.x * dv.y - target.y * dv.x) / determinant : 0.5
            var v = abs(determinant) > 0.001 ? (bv.x * target.y - bv.y * target.x) / determinant : 0.5
            for _ in 0..<10 {
                let p = bilinear(av, bv, cv, dv, u: u, v: v)
                let du = Point(x: (bv.x-av.x)*(1-v)+(cv.x-dv.x)*v,
                               y: (bv.y-av.y)*(1-v)+(cv.y-dv.y)*v)
                let dvect = Point(x: (dv.x-av.x)*(1-u)+(cv.x-bv.x)*u,
                                  y: (dv.y-av.y)*(1-u)+(cv.y-bv.y)*u)
                let ex = p.x-target.x, ey = p.y-target.y
                let det = du.x*dvect.y-du.y*dvect.x
                guard abs(det) > 0.000001 else { break }
                u -= (ex*dvect.y-ey*dvect.x)/det
                v -= (du.x*ey-du.y*ex)/det
            }
            return .init(x: u*geometry.spec.width, y: v*geometry.spec.length)
        }
        let offset = Geo.local(coordinate, origin: anchor1)
        let rotation = Geo.radians(fieldBearing)
        let anchor = geometry.point(anchor1Node)
        let scale = measuredScale ?? 1
        return .init(x: anchor.x + (offset.x * sin(rotation) + offset.y * cos(rotation)) / scale,
                     y: anchor.y + (offset.x * cos(rotation) - offset.y * sin(rotation)) / scale)
    }
}
private func bilinear(_ a: Point, _ b: Point, _ c: Point, _ d: Point, u: Double, v: Double) -> Point {
    .init(x: a.x*(1-u)*(1-v)+b.x*u*(1-v)+c.x*u*v+d.x*(1-u)*v,
          y: a.y*(1-u)*(1-v)+b.y*u*(1-v)+c.y*u*v+d.y*(1-u)*v)
}
enum GeometryError: Error { case invalidAnchorPair, insufficientSeparation }
func anchorDistanceMismatchFraction(_ geometry: FieldGeometry,
                                    firstNode: String, first: Coordinate,
                                    secondNode: String, second: Coordinate) -> Double {
    let templateDistance = (geometry.point(secondNode) - geometry.point(firstNode)).magnitude
    guard templateDistance > 0 else { return .infinity }
    return abs(Geo.distanceMeters(first, second) - templateDistance) / templateDistance
}
enum SecondAnchorDecision: Equatable {
    case measuredCorner, offerStandardExtension, directionBaselineTooShort, fartherThanTemplate
}
struct SecondAnchorAssessment {
    let measuredDistance: Double
    let templateDistance: Double
    let minimumDirectionBaseline: Double
    let decision: SecondAnchorDecision
}
func assessSecondAnchor(_ geometry: FieldGeometry, firstNode: String, first: Coordinate,
                        secondNode: String, second: Coordinate) -> SecondAnchorAssessment {
    let template = (geometry.point(secondNode) - geometry.point(firstNode)).magnitude
    let measured = Geo.distanceMeters(first, second)
    let minimum = max(15, template * 0.35)
    let decision: SecondAnchorDecision
    if measured < minimum { decision = .directionBaselineTooShort }
    else if measured < template * (1 - NavigationThresholds.anchorDistanceToleranceFraction) {
        decision = .offerStandardExtension
    } else if measured > template * (1 + NavigationThresholds.anchorDistanceToleranceFraction) {
        decision = .fartherThanTemplate
    } else { decision = .measuredCorner }
    return .init(measuredDistance: measured, templateDistance: template,
                 minimumDirectionBaseline: minimum, decision: decision)
}
func generateFieldGeometry(_ geometry: FieldGeometry, anchor1Node: String, anchor1: Coordinate,
                           anchor2Node: String, candidate: Coordinate, accuracy: Double = 0) throws -> Calibration {
    let corners: Set<String> = ["A", "B", "C", "D"]
    guard corners.contains(anchor1Node), corners.contains(anchor2Node),
          anchor1Node != anchor2Node else { throw GeometryError.invalidAnchorPair }
    guard Geo.distanceMeters(anchor1, candidate) >= NavigationThresholds.anchorMinimumSeparation else { throw GeometryError.insufficientSeparation }
    let delta = geometry.point(anchor2Node) - geometry.point(anchor1Node)
    let bearing = Geo.bearingDegrees(anchor1, candidate)
    var result = Calibration(anchor1Node: anchor1Node, anchor1: anchor1, anchor2Node: anchor2Node, candidate: candidate,
                             correctedAnchor2: Geo.destinationCoordinate(anchor1, bearing: bearing, distance: delta.magnitude),
                             fieldBearing: bearing - Geo.degrees(atan2(delta.y, delta.x)), accuracy: accuracy,
                             calibratedAt: Date(), generatedGeoNodes: [:])
    result.generatedGeoNodes = Dictionary(uniqueKeysWithValues: geometry.nodes.map { ($0.id, result.coordinate($0.point, geometry: geometry)) })
    return result
}
func generateScaledFieldGeometry(_ geometry: FieldGeometry, anchor1Node: String, anchor1: Coordinate,
                                 anchor2Node: String, measuredAnchor2: Coordinate,
                                 accuracy: Double = 0) throws -> Calibration {
    var result = try generateFieldGeometry(geometry, anchor1Node: anchor1Node, anchor1: anchor1,
                                           anchor2Node: anchor2Node, candidate: measuredAnchor2,
                                           accuracy: accuracy)
    let templateDistance = (geometry.point(anchor2Node)-geometry.point(anchor1Node)).magnitude
    let measuredDistance = Geo.distanceMeters(anchor1, measuredAnchor2)
    guard templateDistance > 0 else { throw GeometryError.invalidAnchorPair }
    result.measuredScale = measuredDistance/templateDistance
    result.correctedAnchor2 = measuredAnchor2
    result.generatedGeoNodes = Dictionary(uniqueKeysWithValues: geometry.nodes.map {
        ($0.id, result.coordinate($0.point, geometry: geometry))
    })
    let scale = result.measuredScale ?? 1
    applyFixedRuleMarkings(to: &result,geometry: geometry,
                           measuredLength: geometry.spec.length*scale,
                           measuredWidth: geometry.spec.width*scale)
    return result
}
func generateMeasuredFieldGeometry(_ geometry: FieldGeometry,
                                   corners: [String: LocationSample]) throws -> Calibration {
    guard let a = corners["A"], let b = corners["B"],
          let c = corners["C"], let d = corners["D"] else { throw GeometryError.invalidAnchorPair }
    let local = [Point(x: 0, y: 0), Geo.local(b.coordinate, origin: a.coordinate),
                 Geo.local(c.coordinate, origin: a.coordinate), Geo.local(d.coordinate, origin: a.coordinate)]
    guard zip(local, Array(local.dropFirst()) + [local[0]]).allSatisfy({ ($0.1-$0.0).magnitude >= NavigationThresholds.anchorMinimumSeparation }) else {
        throw GeometryError.insufficientSeparation
    }
    let turns = (0..<4).map { index -> Double in
        let p0 = local[index], p1 = local[(index+1)%4], p2 = local[(index+2)%4]
        let first = p1-p0, second = p2-p1
        return first.x*second.y-first.y*second.x
    }
    guard turns.allSatisfy({ $0 > 1 }) || turns.allSatisfy({ $0 < -1 }) else { throw GeometryError.invalidAnchorPair }
    let measured = ["A":a.coordinate,"B":b.coordinate,"C":c.coordinate,"D":d.coordinate]
    var result = Calibration(anchor1Node: "A", anchor1: a.coordinate, anchor2Node: "B",
                             candidate: b.coordinate, correctedAnchor2: b.coordinate,
                             fieldBearing: Geo.bearingDegrees(a.coordinate, b.coordinate),
                             accuracy: corners.values.map(\.accuracy).max() ?? 0,
                             calibratedAt: Date(), generatedGeoNodes: [:], measuredCorners: measured)
    result.generatedGeoNodes = Dictionary(uniqueKeysWithValues: geometry.nodes.map {
        ($0.id, result.coordinate($0.point, geometry: geometry))
    })
    let topMidpoint = result.coordinate(.init(x: geometry.spec.width/2,y: 0),geometry: geometry)
    let bottomMidpoint = result.coordinate(.init(x: geometry.spec.width/2,y: geometry.spec.length),geometry: geometry)
    let measuredLength = Geo.distanceMeters(topMidpoint,bottomMidpoint)
    let measuredWidth = (Geo.distanceMeters(a.coordinate,b.coordinate)+Geo.distanceMeters(d.coordinate,c.coordinate))/2
    applyFixedRuleMarkings(to: &result,geometry: geometry,
                           measuredLength: measuredLength,measuredWidth: measuredWidth)
    return result
}

/// Boundary dimensions may change on a constrained site, while competition markings
/// remain rule distances. This remaps penalty/goal areas, penalty marks and 7v7
/// build-out lines after the outer field has been fitted.
private func applyFixedRuleMarkings(to calibration: inout Calibration,geometry: FieldGeometry,
                                    measuredLength: Double,measuredWidth: Double) {
    guard measuredLength > 0, measuredWidth > 0 else { return }
    func mapped(x: Double,y: Double) -> Coordinate {
        if let scale = calibration.measuredScale, scale > 0 {
            // `coordinate` applies the uniform boundary scale. Undo it here so
            // rule distances such as a 9 m penalty mark stay 9 m on the ground.
            return calibration.coordinate(.init(x: x/scale,y: y/scale),geometry: geometry)
        }
        // Four measured corners use a bilinear fit, so express fixed metre
        // offsets as fractions of the measured boundary.
        return calibration.coordinate(
            .init(x: geometry.spec.width*x/measuredWidth,
                  y: geometry.spec.length*y/measuredLength),
            geometry: geometry
        )
    }
    func area(_ prefix: String,width: Double,depth: Double) {
        guard width <= measuredWidth, depth*2 < measuredLength else { return }
        let left = (measuredWidth-width)/2, right = (measuredWidth+width)/2
        for (side,baseline,front) in [("TOP",0.0,depth),("BOTTOM",measuredLength,measuredLength-depth)] {
            calibration.generatedGeoNodes["\(prefix)-\(side)-1"] = mapped(x: left,y: baseline)
            calibration.generatedGeoNodes["\(prefix)-\(side)-2"] = mapped(x: left,y: front)
            calibration.generatedGeoNodes["\(prefix)-\(side)-3"] = mapped(x: right,y: front)
            calibration.generatedGeoNodes["\(prefix)-\(side)-4"] = mapped(x: right,y: baseline)
        }
    }
    area("PA",width: geometry.spec.penaltyWidth,depth: geometry.spec.penaltyDepth)
    if let width = geometry.spec.goalWidth,let depth = geometry.spec.goalDepth {
        area("GA",width: width,depth: depth)
    }
    if geometry.spec.penaltySpot*2 < measuredLength {
        calibration.generatedGeoNodes["SPOT-TOP"] = mapped(x: measuredWidth/2,y: geometry.spec.penaltySpot)
        calibration.generatedGeoNodes["SPOT-BOTTOM"] = mapped(x: measuredWidth/2,y: measuredLength-geometry.spec.penaltySpot)
    }
    if geometry.spec.buildOutLines == true,geometry.spec.penaltyDepth < measuredLength/2 {
        let topY = (geometry.spec.penaltyDepth+measuredLength/2)/2
        calibration.generatedGeoNodes["BOL-TOP-L"] = mapped(x: 0,y: topY)
        calibration.generatedGeoNodes["BOL-TOP-R"] = mapped(x: measuredWidth,y: topY)
        calibration.generatedGeoNodes["BOL-BOTTOM-L"] = mapped(x: 0,y: measuredLength-topY)
        calibration.generatedGeoNodes["BOL-BOTTOM-R"] = mapped(x: measuredWidth,y: measuredLength-topY)
    }
}
enum NavigationThresholds {
    static let sampleWindow = 3.0
    static let anchorMaximumDuration = 20
    static let weakAccuracy = 5.0
    static let clubAnchorMaximumAccuracy = 12.0
    static let anchorDistanceToleranceFraction = 0.15
    static let surveySampleMaximumAccuracy = 15.0
    static let staleSeconds = 5.0
    static let anchorMinimumSeparation = 5.0
    static let directionMinimumTravel = 4.0
    static let alignmentDegrees = 5.0
    static let stableSeconds = 2.0
    static let readyDistance = 1.5
    static let minorCrossTrack = 0.25
    static let majorCrossTrack = 0.75
    static let nearEnd = 5.0
    static let closeEnd = 2.0
}
