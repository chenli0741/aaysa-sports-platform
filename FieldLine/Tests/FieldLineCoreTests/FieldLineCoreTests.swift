import XCTest
@testable import FieldLineCore

final class FieldLineCoreTests: XCTestCase {
    let origin = Coordinate(latitude: 37.3, longitude: -121.9)
    var geometry: FieldGeometry { .generate(.custom(length: 100, width: 60)) }
    func testAllTwelveCornerPairsAtMultipleRotations() throws {
        let pairs = ["A", "B", "C", "D"].flatMap { first in
            ["A", "B", "C", "D"].filter { $0 != first }.map { (first, $0) }
        }
        for rotation in [0.0, 37, 90, 179, 270, 359] {
            for (first, second) in pairs {
                let delta = geometry.point(second) - geometry.point(first)
                let bearing = rotation + Geo.degrees(atan2(delta.y, delta.x))
                let candidate = Geo.destinationCoordinate(origin, bearing: bearing, distance: delta.magnitude * 0.8)
                let calibrated = try generateFieldGeometry(geometry, anchor1Node: first, anchor1: origin, anchor2Node: second, candidate: candidate)
                XCTAssertEqual(Geo.signedAngle(calibrated.fieldBearing-rotation), 0, accuracy: 0.00001)
                XCTAssertEqual(Geo.distanceMeters(origin, calibrated.correctedAnchor2), delta.magnitude, accuracy: 0.00001)
                for node in geometry.nodes {
                    let d = node.point - geometry.point(first)
                    let expected = Geo.destinationCoordinate(origin, bearing: rotation+Geo.degrees(atan2(d.y, d.x)), distance: d.magnitude)
                    XCTAssertLessThan(Geo.distanceMeters(calibrated.generatedGeoNodes[node.id]!, expected), 0.0001)
                    let inverse = calibrated.fieldPosition(of: expected, geometry: geometry)
                    XCTAssertEqual(inverse.x, node.point.x, accuracy: 0.001)
                    XCTAssertEqual(inverse.y, node.point.y, accuracy: 0.001)
                }
                let coords = calibrated.generatedGeoNodes
                XCTAssertEqual(Geo.distanceMeters(coords["A"]!, coords["B"]!), 60, accuracy: 0.01)
                XCTAssertEqual(Geo.distanceMeters(coords["B"]!, coords["C"]!), 100, accuracy: 0.01)
            }
        }
    }
    func testInvalidAndCoincidentAnchorsRejected() {
        for pair in [("A", "A"), ("CENTER", "A"), ("B", "CENTER")] {
            XCTAssertThrowsError(try generateFieldGeometry(geometry, anchor1Node: pair.0, anchor1: origin, anchor2Node: pair.1, candidate: origin))
        }
        XCTAssertThrowsError(try generateFieldGeometry(geometry, anchor1Node: "A", anchor1: origin, anchor2Node: "B", candidate: origin))
    }
    func testClubCornerDistanceCheckAndCoarseGPSGate() {
        let template = (geometry.point("C") - geometry.point("A")).magnitude
        let nearby = Geo.destinationCoordinate(origin, bearing: 45, distance: template * 0.9)
        let implausible = Geo.destinationCoordinate(origin, bearing: 45, distance: template * 0.8)
        XCTAssertEqual(anchorDistanceMismatchFraction(geometry, firstNode: "A", first: origin,
                                                      secondNode: "C", second: nearby), 0.1, accuracy: 0.001)
        XCTAssertLessThan(anchorDistanceMismatchFraction(geometry, firstNode: "A", first: origin,
                                                        secondNode: "C", second: nearby),
                          NavigationThresholds.anchorDistanceToleranceFraction)
        XCTAssertGreaterThan(anchorDistanceMismatchFraction(geometry, firstNode: "A", first: origin,
                                                           secondNode: "C", second: implausible),
                             NavigationThresholds.anchorDistanceToleranceFraction)
        let rough = LocationSample(coordinate: origin, timestamp: Date(), accuracy: 10.9)
        XCTAssertNil(StationaryGPS.aggregate([rough], maximumAccuracy: NavigationThresholds.weakAccuracy,
                                             minimumFixes: 1))
        XCTAssertNotNil(StationaryGPS.aggregate([rough], maximumAccuracy: NavigationThresholds.clubAnchorMaximumAccuracy,
                                                minimumFixes: 1))
    }
    func testShortSecondPointDefinesDirectionAndProjectsTargetCorner() throws {
        let template = (geometry.point("C") - geometry.point("D")).magnitude
        let direction = 78.0
        let shortPoint = Geo.destinationCoordinate(origin, bearing: direction, distance: template * 0.6)
        let assessment = assessSecondAnchor(geometry, firstNode: "D", first: origin,
                                            secondNode: "C", second: shortPoint)
        XCTAssertEqual(assessment.decision, .offerStandardExtension)
        XCTAssertEqual(assessment.measuredDistance, template * 0.6, accuracy: 0.001)
        var calibration = try generateFieldGeometry(geometry, anchor1Node: "D", anchor1: origin,
                                                    anchor2Node: "C", candidate: shortPoint)
        calibration.secondPointIsDirectionOnly = true
        XCTAssertEqual(Geo.distanceMeters(origin, calibration.candidate), template * 0.6, accuracy: 0.001)
        XCTAssertEqual(Geo.distanceMeters(origin, calibration.correctedAnchor2), template, accuracy: 0.001)
        XCTAssertEqual(Geo.bearingDegrees(origin, calibration.correctedAnchor2), direction, accuracy: 0.001)
        XCTAssertEqual(calibration.fieldPosition(of: shortPoint, geometry: geometry).x, 36, accuracy: 0.001)
        let restored = try JSONDecoder().decode(Calibration.self, from: JSONEncoder().encode(calibration))
        XCTAssertEqual(restored.secondPointIsDirectionOnly, true)
        XCTAssertEqual(restored.candidate, shortPoint)
        let tooShort = Geo.destinationCoordinate(origin, bearing: direction, distance: 10)
        XCTAssertEqual(assessSecondAnchor(geometry, firstNode: "D", first: origin,
                                          secondNode: "C", second: tooShort).decision, .directionBaselineTooShort)
        let tooFar = Geo.destinationCoordinate(origin, bearing: direction, distance: 75)
        XCTAssertEqual(assessSecondAnchor(geometry, firstNode: "D", first: origin,
                                          secondNode: "C", second: tooFar).decision, .fartherThanTemplate)
    }
    func testFourMeasuredCornersScaleTemplateIntoActualBoundary() throws {
        func sample(_ x: Double, _ y: Double, accuracy: Double = 3) -> LocationSample {
            let coordinate = Geo.destinationCoordinate(origin,
                bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y))
            return .init(coordinate: coordinate, timestamp: Date(), accuracy: accuracy)
        }
        // The physical field is shorter, narrower and slightly skewed compared with
        // the 100 × 60 m template. Every captured corner must remain authoritative.
        let samples = ["A": sample(0, 0), "B": sample(42, 1),
                       "C": sample(45, 72), "D": sample(-2, 70)]
        let calibration = try generateMeasuredFieldGeometry(geometry, corners: samples)
        XCTAssertTrue(calibration.usesMeasuredBoundary)
        for corner in ["A", "B", "C", "D"] {
            XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes[corner]!, samples[corner]!.coordinate), 0.001)
        }
        let center = calibration.generatedGeoNodes["CENTER"]!
        let expectedCenter = sample((0+42+45-2)/4, (0+1+72+70)/4).coordinate
        XCTAssertLessThan(Geo.distanceMeters(center, expectedCenter), 0.001)
        let inverse = calibration.fieldPosition(of: center, geometry: geometry)
        XCTAssertEqual(inverse.x, 30, accuracy: 0.001)
        XCTAssertEqual(inverse.y, 50, accuracy: 0.001)
        let restored = try JSONDecoder().decode(Calibration.self, from: JSONEncoder().encode(calibration))
        XCTAssertTrue(restored.usesMeasuredBoundary)
        XCTAssertEqual(restored.measuredCorners, calibration.measuredCorners)
    }
    func testExistingSecondAnchorUniformlyScalesStandardTemplate() throws {
        let sevenVSeven = FieldGeometry.generate(.init(
            id: "7v7-test", name: "7v7", length: 60, width: 45,
            penaltyDepth: 10, penaltyWidth: 26, goalDepth: nil, goalWidth: nil,
            centerRadius: 6, penaltySpot: 8, buildOutLines: true
        ))
        let measuredB = Geo.destinationCoordinate(origin, bearing: 82, distance: 31.1)
        let calibration = try generateScaledFieldGeometry(sevenVSeven, anchor1Node: "A", anchor1: origin,
                                                          anchor2Node: "B", measuredAnchor2: measuredB,
                                                          accuracy: 5.2)
        XCTAssertTrue(calibration.usesMeasuredScale)
        XCTAssertEqual(try XCTUnwrap(calibration.measuredScale), 31.1/45, accuracy: 0.000001)
        XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes["A"]!, origin), 0.001)
        XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes["B"]!, measuredB), 0.001)
        XCTAssertEqual(Geo.distanceMeters(calibration.generatedGeoNodes["B"]!, calibration.generatedGeoNodes["C"]!), 60 * 31.1/45, accuracy: 0.001)
        let topGoalMidpoint = Geo.destinationCoordinate(origin,bearing: 82,distance: 31.1/2)
        XCTAssertEqual(Geo.distanceMeters(topGoalMidpoint,calibration.generatedGeoNodes["SPOT-TOP"]!),sevenVSeven.spec.penaltySpot,accuracy: 0.01)
        XCTAssertEqual(Geo.distanceMeters(calibration.generatedGeoNodes["PA-TOP-1"]!,calibration.generatedGeoNodes["PA-TOP-2"]!),sevenVSeven.spec.penaltyDepth,accuracy: 0.01)
        XCTAssertEqual(Geo.distanceMeters(calibration.generatedGeoNodes["PA-TOP-2"]!,calibration.generatedGeoNodes["PA-TOP-3"]!),sevenVSeven.spec.penaltyWidth,accuracy: 0.01)
        let inverse = calibration.fieldPosition(of: calibration.generatedGeoNodes["CENTER"]!, geometry: sevenVSeven)
        XCTAssertEqual(inverse.x, 22.5, accuracy: 0.001)
        XCTAssertEqual(inverse.y, 30, accuracy: 0.001)
        let restored = try JSONDecoder().decode(Calibration.self, from: JSONEncoder().encode(calibration))
        XCTAssertEqual(try XCTUnwrap(restored.measuredScale), 31.1/45, accuracy: 0.000001)
    }
    func testFourMeasuredCornersRejectCrossedCaptureOrder() {
        func sample(_ x: Double, _ y: Double) -> LocationSample {
            .init(coordinate: Geo.destinationCoordinate(origin,
                bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y)), timestamp: Date(), accuracy: 3)
        }
        let crossed = ["A": sample(0, 0), "B": sample(40, 70),
                       "C": sample(40, 0), "D": sample(0, 70)]
        XCTAssertThrowsError(try generateMeasuredFieldGeometry(geometry, corners: crossed))
    }
    func testCrossTrackSignsAndAlongTrackInBothDirections() {
        let end = Geo.destinationCoordinate(origin, bearing: 0, distance: 100)
        let right = Geo.destinationCoordinate(origin, bearing: Geo.degrees(atan2(3.0, 40.0)), distance: 40.1123422403)
        let p = Geo.project(right, start: origin, end: end)
        XCTAssertEqual(p.cross, 3, accuracy: 0.0001)
        XCTAssertEqual(p.along, 40, accuracy: 0.0001)
        let reversed = Geo.project(right, start: end, end: origin)
        XCTAssertEqual(reversed.cross, -3, accuracy: 0.01)
        XCTAssertEqual(reversed.along, 60, accuracy: 0.01)
        let past = Geo.destinationCoordinate(origin, bearing: 0, distance: 102)
        XCTAssertGreaterThan(Geo.project(past, start: origin, end: end).along, 100)
    }
    func testGoalPlacementUsesSymmetricBaselinePairAndOnlyMeasuresGoalWidth() throws {
        let reference2 = Geo.destinationCoordinate(origin, bearing: 90, distance: 45)
        // The goal is deliberately measured elsewhere and at a different angle.
        let looseGoal1 = Geo.destinationCoordinate(origin, bearing: 15, distance: 80)
        let looseGoal2 = Geo.destinationCoordinate(looseGoal1, bearing: 0, distance: 6)
        let setup = GoalPlacementSetup(reference1: origin, reference2: reference2,
                                       measuredGoalEnd1: looseGoal1, measuredGoalEnd2: looseGoal2)
        XCTAssertTrue(setup.isUsable)
        XCTAssertEqual(setup.goalWidth, 6, accuracy: 0.001)
        XCTAssertEqual(Geo.distanceMeters(origin, setup.center), 22.5, accuracy: 0.001)
        XCTAssertEqual(Geo.distanceMeters(origin, setup.target1), 19.5, accuracy: 0.001)
        XCTAssertEqual(Geo.distanceMeters(origin, setup.target2), 25.5, accuracy: 0.001)
        let manuallyEntered = GoalPlacementSetup(reference1: origin, reference2: reference2, goalWidth: 6)
        XCTAssertEqual(Geo.distanceMeters(setup.target1, manuallyEntered.target1), 0, accuracy: 0.001)
        XCTAssertEqual(Geo.distanceMeters(setup.target2, manuallyEntered.target2), 0, accuracy: 0.001)

        let nearSecondPost = Geo.destinationCoordinate(setup.target2, bearing: 90, distance: 2)
        let validation = try XCTUnwrap(setup.validate(post: nearSecondPost))
        XCTAssertEqual(validation.targetIndex, 2)
        XCTAssertEqual(validation.distanceToTarget, 2, accuracy: 0.001)
        XCTAssertEqual(validation.alongOffset, 2, accuracy: 0.001)
    }
    func testGoalPlacementRejectsGoalWiderThanReferencePair() {
        let reference2 = Geo.destinationCoordinate(origin, bearing: 90, distance: 5)
        let goal2 = Geo.destinationCoordinate(origin, bearing: 0, distance: 7)
        let setup = GoalPlacementSetup(reference1: origin, reference2: reference2,
                                       measuredGoalEnd1: origin, measuredGoalEnd2: goal2)
        XCTAssertFalse(setup.isUsable)
        XCTAssertNil(setup.validate(post: origin))
    }
    func testCustomGeometryScalesAndConnectionsAreLegal() {
        let larger = FieldGeometry.generate(.custom(length: 120, width: 72))
        for node in geometry.nodes {
            let scaled = larger.point(node.id)
            XCTAssertEqual(scaled.x, node.point.x*1.2, accuracy: 0.0001)
            XCTAssertEqual(scaled.y, node.point.y*1.2, accuracy: 0.0001)
            XCTAssertTrue((0...120).contains(scaled.y))
            XCTAssertTrue((0...72).contains(scaled.x))
        }
        XCTAssertEqual(Set(geometry.connectedSegments("A").map(\.id)), Set(["AB", "DA"]))
        XCTAssertEqual(geometry.connectedSegments("PA-TOP-2").count, 2)
    }
    func testPersistenceRoundTripKeepsExactGeometry() throws {
        let calibration = try generateFieldGeometry(geometry, anchor1Node: "C", anchor1: origin, anchor2Node: "B", candidate: Geo.destinationCoordinate(origin, bearing: 215, distance: 80))
        let field = SavedField(name: "Test", geometry: geometry, calibration: calibration)
        let data = try JSONEncoder().encode(field)
        let restored = try JSONDecoder().decode(SavedField.self, from: data)
        XCTAssertEqual(restored.id, field.id)
        XCTAssertEqual(restored.calibration!.generatedGeoNodes, field.calibration!.generatedGeoNodes)
        XCTAssertEqual(restored.geometry.nodes.map(\.point), field.geometry.nodes.map(\.point))
    }
    func testManualMarkingRecordPersistsAlongsideOlderRecords() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let manual = MarkingRecord(segmentID: "A → B", startTime: now, endTime: now,
                                   samples: [], maxCrossTrackError: 0, averageCrossTrackError: 0,
                                   manuallyGuided: true)
        XCTAssertEqual(try JSONDecoder().decode(MarkingRecord.self, from: JSONEncoder().encode(manual)).manuallyGuided, true)
        let older = MarkingRecord(segmentID: "B → C", startTime: now, endTime: now,
                                  samples: [], maxCrossTrackError: 0, averageCrossTrackError: 0)
        XCTAssertNil(try JSONDecoder().decode(MarkingRecord.self, from: JSONEncoder().encode(older)).manuallyGuided)
    }
    func testSimulatedCalibrationReturnMarkingAndWeakGPS() {
        var engine = NavigationEngine(start: origin, end: Geo.destinationCoordinate(origin, bearing: 0, distance: 60))
        engine.beginCalibration()
        let date = Date()
        func update(_ distance: Double, _ second: Double, accuracy: Double = 1) {
            let timestamp = date.addingTimeInterval(second)
            engine.update(.init(coordinate: Geo.destinationCoordinate(origin, bearing: 0, distance: distance), timestamp: timestamp, accuracy: accuracy), now: timestamp)
        }
        for step in 0...8 { update(Double(step), Double(step)) }
        XCTAssertEqual(engine.phase, .aligned)
        engine.phase = .returningToStart
        update(3, 9); XCTAssertEqual(engine.phase, .returningToStart)
        update(1, 10); XCTAssertEqual(engine.phase, .readyToMark)
        update(4, 11); XCTAssertEqual(engine.phase, .returningToStart)
        update(0, 12); engine.phase = .marking
        update(20, 13); XCTAssertEqual(engine.remaining, 40, accuracy: 0.001)
        update(30, 14, accuracy: 20)
        XCTAssertTrue(engine.gpsWarning); XCTAssertEqual(engine.instruction, "GPS SIGNAL WEAK")
        XCTAssertEqual(engine.phase, .marking)
        update(63, 15); XCTAssertEqual(engine.instruction, "PASSED END · STOP PAINT")
    }
    func testWrongDirectionAndStaleSample() {
        var engine = NavigationEngine(start: origin, end: Geo.destinationCoordinate(origin, bearing: 0, distance: 60))
        engine.beginCalibration()
        let date = Date()
        for step in 0...8 {
            let timestamp = date.addingTimeInterval(Double(step))
            engine.update(.init(coordinate: Geo.destinationCoordinate(origin, bearing: 180, distance: Double(step)), timestamp: timestamp, accuracy: 1), now: timestamp)
        }
        XCTAssertEqual(engine.instruction, "WRONG DIRECTION")
        XCTAssertEqual(engine.phase, .calibratingDirection)
        engine.update(.init(coordinate: origin, timestamp: date, accuracy: 1), now: date.addingTimeInterval(20))
        XCTAssertTrue(engine.gpsWarning)
    }
    func testSurveyKeepsUnorderedPointsSeparateFromExplicitLines() throws {
        let second = Geo.destinationCoordinate(origin, bearing: 90, distance: 30)
        let third = Geo.destinationCoordinate(second, bearing: 0, distance: 40)
        let points = [origin, second, third].enumerated().map { index, coordinate in
            GPSPointRecord(coordinate: coordinate, recordedAt: Date(timeIntervalSince1970: Double(index)),
                           horizontalAccuracyMeters: Double(index + 1), altitudeMeters: 12.5,
                           verticalAccuracyMeters: 3, speedMetersPerSecond: 0.5, courseDegrees: 90)
        }
        var survey = GPSSurvey(name: "GPS test", points: points)
        XCTAssertTrue(survey.segments.isEmpty)
        XCTAssertEqual(survey.totalSegmentDistanceMeters, 0)
        XCTAssertEqual(survey.distanceMeters(from: points[0].id, to: points[2].id)!, 50, accuracy: 0.001)
        XCTAssertTrue(survey.addSegment(from: points[0].id, to: points[2].id))
        XCTAssertFalse(survey.addSegment(from: points[2].id, to: points[0].id))
        XCTAssertFalse(survey.addSegment(from: points[1].id, to: points[1].id))
        XCTAssertEqual(survey.segments.count, 1)
        XCTAssertEqual(survey.totalSegmentDistanceMeters, 50, accuracy: 0.001)
        let restored = try JSONDecoder().decode(GPSSurvey.self, from: JSONEncoder().encode(survey))
        XCTAssertEqual(restored.points.map(\.coordinate), points.map(\.coordinate))
        XCTAssertEqual(restored.points.map(\.horizontalAccuracyMeters), [1, 2, 3])
        XCTAssertEqual(restored.segments.count, 1)
        XCTAssertEqual(restored.segments[0].fromPointID, points[0].id)
        XCTAssertEqual(restored.segments[0].toPointID, points[2].id)
        let rows = restored.csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].split(separator: ",").count, 14)
        XCTAssertTrue(rows[3].contains("12.5"))
        XCTAssertFalse(rows[0].contains("distance_from_previous"))
        let lineRows = restored.linesCSV(using: nil).split(separator: "\n")
        XCTAssertEqual(lineRows.count, 2)
        XCTAssertTrue(lineRows[1].contains(",manual,1,3,"))
    }
    func testFieldLinesFollowNamedTopologyNotCaptureOrder() throws {
        let field = FieldGeometry.generate(.custom(length: 70, width: 45))
        let captureOrder = ["C", "HL2", "A", "PA-TOP-3", "B", "HL1", "PA-TOP-1",
                            "D", "PA-TOP-4", "PA-TOP-2"]
        var survey = GPSSurvey(name: "unordered", templateID: "custom")
        for node in captureOrder {
            let position = field.point(node)
            let coordinate = Geo.destinationCoordinate(origin,
                bearing: Geo.degrees(atan2(position.x, position.y)), distance: position.magnitude)
            survey.points.append(GPSPointRecord(coordinate: coordinate, recordedAt: Date(),
                                                 horizontalAccuracyMeters: 2, fieldNodeID: node))
        }
        let lines = survey.lines(using: field)
        XCTAssertEqual(Set(lines.map(\.id)), Set([
            "auto-AB-A-PA-TOP-1", "auto-AB-PA-TOP-1-PA-TOP-4", "auto-AB-PA-TOP-4-B",
            "auto-BC-B-HL2", "auto-BC-HL2-C", "auto-CD-C-D",
            "auto-DA-D-HL1", "auto-DA-HL1-A", "auto-HALFWAY",
            "auto-PA-TOP-LINE-1", "auto-PA-TOP-LINE-2", "auto-PA-TOP-LINE-3"
        ]))
        XCTAssertFalse(lines.contains { line in
            let names = Set(survey.points.filter { $0.id == line.fromPointID || $0.id == line.toPointID }
                .compactMap(\.fieldNodeID))
            return names == Set(["A", "C"]) || names == Set(["B", "D"])
        })
        XCTAssertEqual(survey.distanceMeters(from: survey.points[2].id, to: survey.points[4].id)!, 45, accuracy: 0.01)
        XCTAssertFalse(survey.assign("A", to: survey.points[0].id, using: field))
        XCTAssertTrue(survey.assign(nil, to: survey.points[2].id, using: field))
        XCTAssertFalse(survey.lines(using: field).contains { $0.id == "auto-AB-A-PA-TOP-1" })
    }
    func testOldSurveyLoadsWithNoInventedLines() throws {
        let point = GPSPointRecord(coordinate: origin, recordedAt: Date(timeIntervalSince1970: 0),
                                   horizontalAccuracyMeters: 3)
        let oldSurvey = GPSSurvey(name: "旧采点", points: [point])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldSurvey)) as? [String: Any])
        object.removeValue(forKey: "segments")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(GPSSurvey.self, from: oldData)
        XCTAssertEqual(restored.points.map(\.id), [point.id])
        XCTAssertTrue(restored.segments.isEmpty)
    }
    func testSurveyInferenceFindsCornersAndPenaltyFromUnorderedFieldSamples() throws {
        // Metre offsets mirror an actual walk around a field plus two interior marks;
        // the geographic origin is deliberately synthetic.
        let records = survey23Records()
        let inference = try XCTUnwrap(SurveyInference.suggest(for: records))
        XCTAssertEqual(Set(inference.cornerPointIDs), Set([records[4].id, records[8].id, records[12].id, records[17].id]))
        XCTAssertEqual(Set(inference.penaltyFrontPointIDs), Set([records[18].id, records[19].id]))
        XCTAssertEqual(Set(inference.goalFrontPointIDs), Set([records[20].id, records[21].id]))
        XCTAssertEqual(inference.penaltySpotPointID, records[22].id)
        XCTAssertEqual(inference.lengthMeters, 57, accuracy: 1)
        XCTAssertEqual(inference.widthMeters, 37.6, accuracy: 1)
        var survey = GPSSurvey(name: "field", points: records)
        var spec = TemplateSpec.custom(length: 57, width: 38)
        spec.goalDepth = 5
        spec.goalWidth = 8
        for (pointID, nodeID) in inference.assignments {
            XCTAssertTrue(survey.assign(nodeID, to: pointID, using: FieldGeometry.generate(spec)))
        }
        let lines = survey.lines(using: FieldGeometry.generate(spec))
        XCTAssertEqual(lines.filter(\.isAutomatic).count, 6) // 4 sides + both measured fronts
        XCTAssertFalse(lines.contains { $0.fromPointID == records[17].id && $0.toPointID == records[18].id })
    }
    func testSurveyReconstructionCentersAndMirrorsInteriorMarks() throws {
        let records = survey23Records()
        let model = try XCTUnwrap(SurveyReconstruction.build(from: records))
        XCTAssertEqual(model.lines.count, 17)
        XCTAssertEqual(model.marks.count, 2)
        XCTAssertEqual(Set(model.inference.penaltyFrontPointIDs), Set([records[18].id, records[19].id]))
        XCTAssertEqual(Set(model.inference.goalFrontPointIDs), Set([records[20].id, records[21].id]))
        XCTAssertEqual(model.inference.penaltySpotPointID, records[22].id)
        let a = records.first { $0.id == model.inference.cornerPointIDs[0] }!.coordinate
        let b = records.first { $0.id == model.inference.cornerPointIDs[1] }!.coordinate
        let d = records.first { $0.id == model.inference.cornerPointIDs[3] }!.coordinate
        let c = records.first { $0.id == model.inference.cornerPointIDs[2] }!.coordinate
        func midpoint(_ p: Point, _ q: Point) -> Point { Point(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2) }
        let start = midpoint(Geo.local(a, origin: a), Geo.local(b, origin: a))
        let end = midpoint(Geo.local(c, origin: a), Geo.local(d, origin: a))
        let axis = end - start
        func local(_ coordinate: Coordinate) -> Point { Geo.local(coordinate, origin: a) }
        func crossAxis(_ point: Point) -> Double {
            let offset = point - start
            return abs(offset.x * axis.y - offset.y * axis.x) / axis.magnitude
        }
        for feature in [ReconstructionFeature.penaltyArea, .goalArea] {
            let fronts = model.lines.filter { $0.feature == feature && $0.id.contains("front") }
            XCTAssertEqual(fronts.count, 2)
            let fitted = try XCTUnwrap(fronts.first { $0.source == .inferred })
            let mirrored = try XCTUnwrap(fronts.first { $0.source == .mirrored })
            let fittedCenter = midpoint(local(fitted.from), local(fitted.to))
            let mirroredCenter = midpoint(local(mirrored.from), local(mirrored.to))
            XCTAssertLessThan(crossAxis(fittedCenter), 0.02)
            XCTAssertLessThan(crossAxis(mirroredCenter), 0.02)
            XCTAssertLessThan((midpoint(fittedCenter, mirroredCenter) - midpoint(start, end)).magnitude, 0.05)
            XCTAssertEqual(fitted.meters, mirrored.meters, accuracy: 0.5)
        }
        let centered = try XCTUnwrap(model.marks.first { $0.source == .inferred })
        let mirrored = try XCTUnwrap(model.marks.first { $0.source == .mirrored })
        XCTAssertLessThan(crossAxis(local(centered.coordinate)), 0.02)
        XCTAssertLessThan(crossAxis(local(mirrored.coordinate)), 0.02)
        XCTAssertLessThan((midpoint(local(centered.coordinate), local(mirrored.coordinate)) - midpoint(start, end)).magnitude, 0.05)
        XCTAssertNotEqual(centered.coordinate, records[22].coordinate)
        XCTAssertTrue(model.csv.contains("penaltyArea-front-mirrored"))
        XCTAssertTrue(model.csv.contains("penalty-spot-centered,point,penaltySpot,inferred"))
        let shuffled = Array(records.reversed())
        let reordered = try XCTUnwrap(SurveyReconstruction.build(from: shuffled))
        XCTAssertEqual(Set(reordered.inference.cornerPointIDs), Set(model.inference.cornerPointIDs))
        XCTAssertEqual(Set(reordered.inference.penaltyFrontPointIDs), Set(model.inference.penaltyFrontPointIDs))
        XCTAssertEqual(Set(reordered.inference.goalFrontPointIDs), Set(model.inference.goalFrontPointIDs))
        XCTAssertEqual(reordered.inference.penaltySpotPointID, model.inference.penaltySpotPointID)
        XCTAssertEqual(reordered.lines.count, model.lines.count)
    }
    func testSurveyReconstructionGrowsAsPointsArrive() throws {
        let records = survey23Records()
        let outline = try XCTUnwrap(SurveyReconstruction.build(from: Array(records.prefix(18))))
        XCTAssertEqual(outline.lines.count, 5) // Four boundary sides and halfway line.
        XCTAssertTrue(outline.inference.penaltyFrontPointIDs.isEmpty)
        let penalty = try XCTUnwrap(SurveyReconstruction.build(from: Array(records.prefix(20))))
        XCTAssertEqual(penalty.lines.count, 11)
        XCTAssertEqual(Set(penalty.inference.penaltyFrontPointIDs), Set([records[18].id, records[19].id]))
        let goal = try XCTUnwrap(SurveyReconstruction.build(from: Array(records.prefix(22))))
        XCTAssertEqual(goal.lines.count, 17)
        XCTAssertEqual(Set(goal.inference.goalFrontPointIDs), Set([records[20].id, records[21].id]))
        XCTAssertTrue(goal.marks.isEmpty)
        let spot = try XCTUnwrap(SurveyReconstruction.build(from: records))
        XCTAssertEqual(spot.lines.count, 17)
        XCTAssertEqual(spot.marks.count, 2)
    }
    func testSurveyClassifierRecognizesSevenVSevenBuildOutLines() throws {
        func record(_ x: Double,_ y: Double) -> GPSPointRecord {
            .init(coordinate: Geo.destinationCoordinate(origin,bearing: Geo.degrees(atan2(x,y)),distance: hypot(x,y)),
                  recordedAt: Date(),horizontalAccuracyMeters: 3)
        }
        let records = [(0,0),(45,0),(45,60),(0,60),(0,20),(45,20),(0,40),(45,40)].map {
            record(Double($0.0),Double($0.1))
        }
        let inference = try XCTUnwrap(SurveyInference.suggest(for: records))
        XCTAssertEqual(inference.buildOutLinePointIDs.count,2)
        let result = SurveyFieldClassifier.classify(inference)
        XCTAssertEqual(result.templateID,"7v7")
        XCTAssertGreaterThan(result.confidence,0.9)
    }
    func testSurveyClassifierRecognizesStandardGoalArea() throws {
        var inference = try XCTUnwrap(SurveyInference.suggest(for: survey23Records()))
        inference.buildOutLinePointIDs = []
        inference.goalFrontPointIDs = [UUID(),UUID()]
        let result = SurveyFieldClassifier.classify(inference)
        XCTAssertNotEqual(result.templateID,"7v7")
        XCTAssertEqual(result.title,"标准场地")
        XCTAssertGreaterThan(result.confidence,0.9)
    }
    func testThreeSecondStationaryAggregationRejectsJumpAndPreservesRawFixes() throws {
        let started = Date(timeIntervalSince1970: 1_000)
        func fix(_ x: Double, _ y: Double, _ seconds: Double, _ accuracy: Double) -> LocationSample {
            .init(coordinate: Geo.destinationCoordinate(origin,
                bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y)),
                timestamp: started.addingTimeInterval(seconds), accuracy: accuracy)
        }
        let fixes = [fix(0, 0, 0, 3), fix(0.5, 0.2, 1, 4),
                     fix(-0.3, 0.2, 2, 3.5), fix(20, 0, 3, 3)]
        let result = try XCTUnwrap(StationaryGPS.aggregate(fixes, maximumAccuracy: 15))
        XCTAssertEqual(result.receivedFixes.count, 4)
        XCTAssertEqual(result.acceptedFixes.count, 3)
        XCTAssertEqual(result.location.accuracy, 4)
        XCTAssertLessThan(Geo.distanceMeters(result.location.coordinate, origin), 1)
        XCTAssertLessThan(result.spreadMeters, 1)
        XCTAssertNil(StationaryGPS.aggregate(Array(fixes.prefix(2)), maximumAccuracy: 15))
        let fallback = try XCTUnwrap(StationaryGPS.aggregate([fixes[0]], maximumAccuracy: 15, minimumFixes: 1))
        XCTAssertEqual(fallback.acceptedFixes.count, 1)
        XCTAssertEqual(fallback.location.accuracy, 3)
        XCTAssertEqual(fallback.spreadMeters, 0)
        XCTAssertEqual(StationaryGPS.aggregate(fixes + [fix(0, 0, 0, 3)], maximumAccuracy: 15)?.receivedFixes.count, 4)
        XCTAssertNil(StationaryGPS.aggregate([fix(0, 0, 4, 10.9)],
                                            maximumAccuracy: 5, minimumFixes: 1))
        XCTAssertNotNil(StationaryGPS.aggregate([fix(0, 0, 4, 5)],
                                               maximumAccuracy: 5, minimumFixes: 1))

        var point = GPSPointRecord(coordinate: result.location.coordinate,
                                   recordedAt: result.location.timestamp,
                                   horizontalAccuracyMeters: result.location.accuracy)
        point.samplingDurationSeconds = 3
        point.samplingSpreadMeters = result.spreadMeters
        let acceptedTimes = Set(result.acceptedFixes.map(\.timestamp))
        point.rawFixes = result.receivedFixes.map {
            GPSFixRecord(coordinate: $0.coordinate, recordedAt: $0.timestamp,
                         horizontalAccuracyMeters: $0.accuracy,
                         usedInAverage: acceptedTimes.contains($0.timestamp))
        }
        let survey = GPSSurvey(name: "averaged", points: [point])
        let restored = try JSONDecoder().decode(GPSSurvey.self, from: JSONEncoder().encode(survey))
        XCTAssertEqual(restored.points[0].rawFixes?.count, 4)
        XCTAssertEqual(restored.points[0].rawFixes?.filter(\.usedInAverage).count, 3)
        XCTAssertEqual(restored.rawFixesCSV.split(separator: "\n").count, 5)
        XCTAssertTrue(restored.csv.contains(",3.0,3,"))
    }
    func test7v7ReconstructionUsesBuildOutLinesWithoutGoalArea() throws {
        let model = try XCTUnwrap(SurveyReconstruction.build(from: survey23Records(), templateID: "7v7"))
        XCTAssertTrue(model.inference.goalFrontPointIDs.isEmpty)
        XCTAssertFalse(model.lines.contains { $0.feature == .goalArea })
        XCTAssertEqual(model.lines.filter { $0.feature == .buildOut }.count, 2)
        XCTAssertEqual(model.lines.count, 13)
        XCTAssertEqual(model.marks.count, 2)
    }
    func testSaved7v7SurveyKeepsMeasuredPenaltyDimensions() throws {
        let records = survey23Records()
        let model = try XCTUnwrap(SurveyReconstruction.build(from: records, templateID: "7v7"))
        let template = TemplateSpec(id: "7v7", name: "7v7", length: 60, width: 45,
                                    penaltyDepth: 10, penaltyWidth: 26,
                                    goalDepth: nil, goalWidth: nil,
                                    centerRadius: 6, penaltySpot: 8, buildOutLines: true)
        let measured = model.applyingSurveyDimensions(to: template)
        XCTAssertEqual(measured.length, model.inference.lengthMeters, accuracy: 0.01)
        XCTAssertEqual(measured.width, model.inference.widthMeters, accuracy: 0.01)
        XCTAssertEqual(measured.penaltyWidth, 21, accuracy: 1)
        XCTAssertEqual(measured.penaltyDepth, 12, accuracy: 1)
        XCTAssertEqual(measured.penaltySpot, 11, accuracy: 1)
        XCTAssertNil(measured.goalWidth)
        XCTAssertNil(measured.goalDepth)

        let geometry = FieldGeometry.generate(measured)
        let pointsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let corners = Dictionary(uniqueKeysWithValues: zip(["A", "B", "C", "D"], model.inference.cornerPointIDs).map {
            ($0.0, LocationSample(coordinate: pointsByID[$0.1]!.coordinate,
                                  timestamp: Date(), accuracy: 4))
        })
        let calibration = try generateMeasuredFieldGeometry(geometry, corners: corners)
        let fitted = try XCTUnwrap(model.lines.first { $0.id == "penaltyArea-front-fitted" })
        let spot = try XCTUnwrap(model.marks.first { $0.id == "penalty-spot-centered" })
        XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes["PA-TOP-2"]!, fitted.from), 1)
        XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes["PA-TOP-3"]!, fitted.to), 1)
        XCTAssertLessThan(Geo.distanceMeters(calibration.generatedGeoNodes["SPOT-TOP"]!, spot.coordinate), 1)
    }
    private func survey23Records() -> [GPSPointRecord] {
        let positions: [(Double, Double)] = [
            (22.51,30.19),(38.54,20.63),(45.03,16.19),(52.57,11.52),(68.42,0.98),
            (63.93,-5.94),(60.05,-12.40),(52.07,-24.70),(48.36,-30.43),(30.53,-20.98),
            (23.19,-16.23),(14.78,-10.76),(0,0),(4.25,6.47),(8.10,12.41),
            (13.04,19.28),(16.94,25.15),(20.60,31.81),(25.73,19.21),(15.48,0.82),
            (16.91,15.71),(12.50,10.25),(20.15,11.14)
        ]
        return positions.map { x, y in
            GPSPointRecord(coordinate: Geo.destinationCoordinate(origin,
                bearing: Geo.degrees(atan2(x, y)), distance: hypot(x, y)), recordedAt: Date(),
                horizontalAccuracyMeters: 4)
        }
    }
    func test7v7HasBuildOutLinesAndNoGoalAreas() {
        var spec = TemplateSpec.custom(length: 60, width: 45)
        spec.id = "7v7"
        spec.penaltyDepth = 10
        spec.goalDepth = nil
        spec.goalWidth = nil
        spec.buildOutLines = true
        let field = FieldGeometry.generate(spec)
        XCTAssertFalse(field.nodes.contains { $0.id.hasPrefix("GA-") })
        XCTAssertFalse(field.segments.contains { $0.id.hasPrefix("GA-") })
        XCTAssertEqual(field.point("BOL-TOP-L"), Point(x: 0, y: 20))
        XCTAssertEqual(field.point("BOL-TOP-R"), Point(x: 45, y: 20))
        XCTAssertEqual(field.point("BOL-BOTTOM-L"), Point(x: 0, y: 40))
        XCTAssertEqual(field.point("BOL-BOTTOM-R"), Point(x: 45, y: 40))
        XCTAssertEqual(field.connectedSegments("BOL-TOP-L").map(\.id), ["BOL-TOP"])
        XCTAssertEqual(field.connectedSegments("BOL-BOTTOM-R").map(\.id), ["BOL-BOTTOM"])
    }
    func testSaved7v7MigrationKeepsCalibrationAndAddsNewCoordinates() throws {
        var spec = TemplateSpec.custom(length: 60, width: 45)
        spec.id = "7v7"
        var oldGeometry = FieldGeometry.generate(spec)
        oldGeometry.generationStrategyVersion = 1
        let candidate = Geo.destinationCoordinate(origin, bearing: 62, distance: 43)
        let calibration = try generateFieldGeometry(oldGeometry, anchor1Node: "A", anchor1: origin,
                                                    anchor2Node: "B", candidate: candidate)
        let saved = SavedField(name: "Old field", geometry: oldGeometry, calibration: calibration)
        let updated = migrateSaved7v7Field(saved)
        XCTAssertEqual(updated.id, saved.id)
        XCTAssertEqual(updated.calibration!.anchor1, calibration.anchor1)
        XCTAssertEqual(updated.calibration!.correctedAnchor2, calibration.correctedAnchor2)
        XCTAssertEqual(updated.geometry.generationStrategyVersion, 2)
        XCTAssertNil(updated.calibration!.generatedGeoNodes["GA-TOP-1"])
        XCTAssertNotNil(updated.calibration!.generatedGeoNodes["BOL-TOP-L"])
        XCTAssertEqual(updated.calibration!.generatedGeoNodes["A"], origin)
        XCTAssertEqual(migrateSaved7v7Field(updated).geometry.segments.map(\.id), updated.geometry.segments.map(\.id))
    }
}
