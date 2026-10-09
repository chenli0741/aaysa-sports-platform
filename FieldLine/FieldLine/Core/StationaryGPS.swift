import Foundation

struct StationaryGPSResult: Sendable {
    var location: LocationSample
    var receivedFixes: [LocationSample]
    var acceptedFixes: [LocationSample]
    /// Maximum distance of an accepted fix from the weighted center. This measures
    /// short-term scatter, not absolute positional error.
    var spreadMeters: Double
}

enum StationaryGPS {
    static func aggregate(_ fixes: [LocationSample], maximumAccuracy: Double,
                          minimumFixes: Int = 3) -> StationaryGPSResult? {
        var seenTimestamps = Set<Date>()
        let unique = fixes.filter { seenTimestamps.insert($0.timestamp).inserted }
        let valid = unique.filter { $0.accuracy >= 0 && $0.accuracy <= maximumAccuracy }
        guard valid.count >= minimumFixes, let reference = valid.first else { return nil }
        let positions = valid.map { Geo.local($0.coordinate, origin: reference.coordinate) }
        let xs = positions.map(\.x).sorted(), ys = positions.map(\.y).sorted()
        let median = Point(x: xs[xs.count / 2], y: ys[ys.count / 2])
        let accepted = zip(valid, positions).filter {
            ($0.1 - median).magnitude <= max(2, min(maximumAccuracy, $0.0.accuracy * 1.5))
        }
        guard accepted.count >= minimumFixes else { return nil }
        let weight = accepted.reduce(0.0) { $0 + 1 / max(1, pow($1.0.accuracy, 2)) }
        let x = accepted.reduce(0.0) { $0 + $1.1.x / max(1, pow($1.0.accuracy, 2)) } / weight
        let y = accepted.reduce(0.0) { $0 + $1.1.y / max(1, pow($1.0.accuracy, 2)) } / weight
        let center = Geo.destinationCoordinate(reference.coordinate,
            bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y))
        let spread = accepted.map { hypot($0.1.x - x, $0.1.y - y) }.max() ?? 0
        // Do not divide Core Location's uncertainty by sqrt(n): sequential fixes may
        // share the same systematic error. Report the worst accepted radius instead.
        let reportedAccuracy = accepted.map { $0.0.accuracy }.max() ?? reference.accuracy
        let location = LocationSample(coordinate: center,
            timestamp: accepted.map { $0.0.timestamp }.max() ?? reference.timestamp,
            accuracy: reportedAccuracy)
        return .init(location: location, receivedFixes: unique,
                     acceptedFixes: accepted.map { $0.0 }, spreadMeters: spread)
    }
}
