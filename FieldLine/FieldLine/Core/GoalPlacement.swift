import Foundation

struct GoalPostValidation: Equatable, Sendable {
    var targetIndex: Int
    var target: Coordinate
    var distanceToTarget: Double
    /// Positive means the sampled post is farther toward reference point 2.
    var alongOffset: Double
    var crossTrack: Double
}

struct GoalPlacementSetup: Equatable, Sendable {
    var reference1: Coordinate
    var reference2: Coordinate
    var goalWidth: Double

    var referenceDistance: Double { Geo.distanceMeters(reference1, reference2) }
    var center: Coordinate {
        Geo.destinationCoordinate(reference1,
                                  bearing: Geo.bearingDegrees(reference1, reference2),
                                  distance: referenceDistance / 2)
    }
    var target1: Coordinate {
        Geo.destinationCoordinate(reference1,
                                  bearing: Geo.bearingDegrees(reference1, reference2),
                                  distance: (referenceDistance - goalWidth) / 2)
    }
    var target2: Coordinate {
        Geo.destinationCoordinate(reference1,
                                  bearing: Geo.bearingDegrees(reference1, reference2),
                                  distance: (referenceDistance + goalWidth) / 2)
    }
    var isUsable: Bool {
        referenceDistance >= NavigationThresholds.anchorMinimumSeparation &&
        goalWidth >= 1 && goalWidth < referenceDistance
    }

    init(reference1: Coordinate, reference2: Coordinate, goalWidth: Double) {
        self.reference1 = reference1
        self.reference2 = reference2
        self.goalWidth = goalWidth
    }

    init(reference1: Coordinate, reference2: Coordinate,
         measuredGoalEnd1: Coordinate, measuredGoalEnd2: Coordinate) {
        self.init(reference1: reference1, reference2: reference2,
                  goalWidth: Geo.distanceMeters(measuredGoalEnd1, measuredGoalEnd2))
    }

    func validate(post sample: Coordinate) -> GoalPostValidation? {
        guard isUsable else { return nil }
        let distance1 = Geo.distanceMeters(sample, target1)
        let distance2 = Geo.distanceMeters(sample, target2)
        let targetIndex = distance1 <= distance2 ? 1 : 2
        let target = targetIndex == 1 ? target1 : target2
        let projection = Geo.project(sample, start: reference1, end: reference2)
        let targetAlong = targetIndex == 1
            ? (referenceDistance - goalWidth) / 2
            : (referenceDistance + goalWidth) / 2
        return .init(targetIndex: targetIndex,
                     target: target,
                     distanceToTarget: min(distance1, distance2),
                     alongOffset: projection.along - targetAlong,
                     crossTrack: projection.cross)
    }
}
