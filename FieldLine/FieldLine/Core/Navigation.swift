import Foundation

struct LocationSample: Codable, Sendable {
    var coordinate: Coordinate
    var timestamp: Date
    var accuracy: Double
}
enum MarkingPhase: String, Codable, Sendable {
    case lineSelected, calibratingDirection, aligned, returningToStart, readyToMark, marking, segmentComplete
    var title: String {
        switch self {
        case .lineSelected: "选择线段"
        case .calibratingDirection: "方向校准 · 不开喷"
        case .aligned: "ALIGNED · 已对准"
        case .returningToStart: "倒回起点 · 不开喷"
        case .readyToMark: "READY TO MARK"
        case .marking: "划线中"
        case .segmentComplete: "完成 · 关闭喷漆"
        }
    }
}
struct NavigationEngine: Sendable {
    var phase: MarkingPhase = .lineSelected
    var start: Coordinate
    var end: Coordinate
    var cross = 0.0
    var along = 0.0
    var remaining = 0.0
    var startDistance = 0.0
    var headingError: Double?
    var gpsWarning = true
    var accuracy = 0.0
    var samples: [LocationSample] = []
    var stableSince: Date?
    var instruction: String {
        if gpsWarning { return "GPS SIGNAL WEAK" }
        if phase == .segmentComplete { return "STOP PAINT" }
        if phase == .returningToStart { return "RETURN TO START" }
        if phase == .readyToMark { return "READY TO MARK" }
        if phase == .aligned { return "ALIGNED" }
        if phase == .marking {
            if remaining < -NavigationThresholds.readyDistance { return "PASSED END · STOP PAINT" }
            if remaining <= NavigationThresholds.readyDistance { return "STOP PAINT" }
            if cross > NavigationThresholds.minorCrossTrack { return "LEFT ←" }
            if cross < -NavigationThresholds.minorCrossTrack { return "RIGHT →" }
        }
        guard let headingError else { return "向前推行以测量方向" }
        if abs(headingError) > 90 { return "WRONG DIRECTION" }
        if headingError > NavigationThresholds.alignmentDegrees { return "LEFT ←" }
        if headingError < -NavigationThresholds.alignmentDegrees { return "RIGHT →" }
        return "STRAIGHT ↑"
    }
    mutating func beginCalibration() {
        phase = .calibratingDirection
        samples = []
        stableSince = nil
        headingError = nil
    }
    mutating func update(_ sample: LocationSample, now: Date = Date()) {
        accuracy = sample.accuracy
        gpsWarning = sample.accuracy < 0 || sample.accuracy > NavigationThresholds.weakAccuracy || abs(now.timeIntervalSince(sample.timestamp)) > NavigationThresholds.staleSeconds
        guard !gpsWarning else { stableSince = nil; headingError = nil; samples.removeAll(); return }
        let projection = Geo.project(sample.coordinate, start: start, end: end)
        cross = projection.cross; along = projection.along; remaining = projection.length - along
        startDistance = Geo.distanceMeters(start, sample.coordinate)
        samples.append(sample)
        samples.removeAll { sample.timestamp.timeIntervalSince($0.timestamp) > 20 }
        headingError = nil
        if let previous = samples.reversed().first(where: { Geo.distanceMeters($0.coordinate, sample.coordinate) >= NavigationThresholds.directionMinimumTravel }) {
            headingError = Geo.signedAngle(Geo.bearingDegrees(previous.coordinate, sample.coordinate) - Geo.bearingDegrees(start, end))
        }
        if phase == .calibratingDirection {
            if let headingError, abs(headingError) <= NavigationThresholds.alignmentDegrees {
                if stableSince == nil { stableSince = sample.timestamp }
                if sample.timestamp.timeIntervalSince(stableSince!) >= NavigationThresholds.stableSeconds { phase = .aligned }
            } else { stableSince = nil }
        }
        if phase == .returningToStart && startDistance <= NavigationThresholds.readyDistance { phase = .readyToMark }
        if phase == .readyToMark && startDistance > NavigationThresholds.readyDistance { phase = .returningToStart }
    }
}
struct MarkingRecord: Codable, Identifiable {
    var id = UUID()
    var segmentID: String
    var startTime: Date
    var endTime: Date
    var samples: [LocationSample]
    var maxCrossTrackError: Double
    var averageCrossTrackError: Double
    var manuallyGuided: Bool? = nil
}
struct SavedField: Codable, Identifiable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var geometry: FieldGeometry
    var calibration: Calibration?
    var sessions: [MarkingRecord] = []
}
