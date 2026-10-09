import SwiftUI
import CoreLocation

@MainActor final class FieldStore: ObservableObject {
    @Published var fields: [SavedField] = []
    @Published private(set) var gpsSurveys: [GPSSurvey] = []
    @Published var error: String?
    let templates: [TemplateSpec]
    private let url: URL
    private let surveysURL: URL
    private var loadFailed = false
    private var surveysLoadFailed = false
    init() {
        url = URL.documentsDirectory.appending(path: "fieldline-fields.json")
        surveysURL = URL.documentsDirectory.appending(path: "fieldline-gps-surveys.json")
        do {
            guard let source = Bundle.main.url(forResource: "Templates", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            templates = try JSONDecoder().decode([TemplateSpec].self, from: Data(contentsOf: source))
        } catch { templates = []; self.error = "模板读取失败：\(error.localizedDescription)" }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let saved = try JSONDecoder().decode([SavedField].self, from: Data(contentsOf: url))
                let upgraded = saved.map(migrateSaved7v7Field)
                if zip(saved, upgraded).contains(where: { $0.0.geometry.generationStrategyVersion != $0.1.geometry.generationStrategyVersion }) {
                    try JSONEncoder().encode(upgraded).write(to: url, options: .atomic)
                }
                fields = upgraded
            }
            catch { loadFailed = true; self.error = "场地文件读取失败，原文件未覆盖：\(error.localizedDescription)" }
        }
        if FileManager.default.fileExists(atPath: surveysURL.path) {
            do { gpsSurveys = try JSONDecoder().decode([GPSSurvey].self, from: Data(contentsOf: surveysURL)) }
            catch { surveysLoadFailed = true; self.error = "GPS 记录文件读取失败，原文件未覆盖：\(error.localizedDescription)" }
        }
        upgradeSavedSurveyFields()
    }
    func save(_ field: SavedField) {
        guard !loadFailed else { error = "原场地文件无法读取，已阻止覆盖。请先备份并修复本地文件。"; return }
        var next = fields
        if let index = next.firstIndex(where: { $0.id == field.id }) { next[index] = field }
        else { next.insert(field, at: 0) }
        do {
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            fields = next
            error = nil
        } catch { self.error = "保存失败：\(error.localizedDescription)" }
    }
    @discardableResult func createGPSSurvey() -> UUID? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let survey = GPSSurvey(name: "采点记录 \(formatter.string(from: Date()))", templateID: nil)
        return saveSurvey(survey) ? survey.id : nil
    }
    func surveyGeometry(_ survey: GPSSurvey) -> FieldGeometry? {
        guard let templateID = survey.templateID,
              let spec = templates.first(where: { $0.id == templateID }) else { return nil }
        return .generate(spec)
    }
    @discardableResult func setGPSSurveyTemplate(_ surveyID: UUID, to templateID: String?) -> Bool {
        guard templateID == nil || templates.contains(where: { $0.id == templateID }) else {
            error = "找不到这个场地模板"; return false
        }
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }) else {
            error = "找不到这份采点记录"; return false
        }
        survey.templateID = templateID
        return saveSurvey(survey)
    }
    @discardableResult func assignGPSPoint(_ pointID: UUID, in surveyID: UUID, to nodeID: String?) -> Bool {
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }),
              let geometry = surveyGeometry(survey) else {
            error = "请先选择场地类型"; return false
        }
        guard survey.assign(nodeID, to: pointID, using: geometry) else {
            error = "场地位置无效，或已经分配给其他采点"; return false
        }
        return saveSurvey(survey)
    }
    @discardableResult func applyGPSSurveyInference(_ inference: FieldSurveyInference, to surveyID: UUID) -> Bool {
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }),
              let geometry = surveyGeometry(survey) else {
            error = "请先选择场地类型"; return false
        }
        guard survey.points.allSatisfy({ $0.fieldNodeID == nil }) else {
            error = "这份记录已有场地位置标记，请在点位列表中调整"; return false
        }
        for (pointID, nodeID) in inference.assignments {
            guard geometry.nodes.contains(where: { $0.id == nodeID }) else { continue }
            guard survey.assign(nodeID, to: pointID, using: geometry) else {
                error = "识别结果与当前场地模板不匹配"; return false
            }
        }
        return saveSurvey(survey)
    }
    @discardableResult func appendGPSPoint(_ point: GPSPointRecord, to surveyID: UUID) -> Bool {
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }) else {
            error = "找不到这份采点记录"; return false
        }
        if let nodeID = point.fieldNodeID {
            guard let geometry = surveyGeometry(survey),
                  geometry.nodes.contains(where: { $0.id == nodeID }),
                  !survey.points.contains(where: { $0.fieldNodeID == nodeID }) else {
                error = "所选场地位置无效，或已被记录"; return false
            }
        }
        survey.points.append(point)
        return saveSurvey(survey)
    }
    @discardableResult func addGPSSegment(to surveyID: UUID, from startID: UUID, to endID: UUID) -> Bool {
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }) else {
            error = "找不到这份采点记录"; return false
        }
        guard !survey.lines(using: surveyGeometry(survey)).contains(where: {
            ($0.fromPointID == startID && $0.toPointID == endID) ||
            ($0.fromPointID == endID && $0.toPointID == startID)
        }) else {
            error = "这两个点已经连成场地线"; return false
        }
        guard survey.addSegment(from: startID, to: endID) else {
            error = "请选择两个不同的已有点，且不要重复连线"; return false
        }
        return saveSurvey(survey)
    }
    @discardableResult func deleteGPSSegment(_ segmentID: UUID, from surveyID: UUID) -> Bool {
        guard var survey = gpsSurveys.first(where: { $0.id == surveyID }) else {
            error = "找不到这份采点记录"; return false
        }
        guard survey.segments.contains(where: { $0.id == segmentID }) else {
            error = "找不到这条线段"; return false
        }
        survey.segments.removeAll { $0.id == segmentID }
        return saveSurvey(survey)
    }
    @discardableResult func renameGPSSurvey(_ id: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "记录名称不能为空"; return false }
        guard var survey = gpsSurveys.first(where: { $0.id == id }) else { error = "找不到这份采点记录"; return false }
        survey.name = trimmed
        return saveSurvey(survey)
    }
    @discardableResult func deleteGPSSurvey(_ id: UUID) -> Bool {
        guard gpsSurveys.contains(where: { $0.id == id }) else { error = "找不到这份采点记录"; return false }
        return writeSurveys(gpsSurveys.filter { $0.id != id })
    }
    @discardableResult func saveGPSSurveyAsField(_ surveyID: UUID, name: String,
                                                 templateID explicitTemplateID: String? = nil) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "球场名称不能为空"; return nil }
        guard let survey = gpsSurveys.first(where: { $0.id == surveyID }),
              let inference = SurveyInference.suggest(for: survey.points) else {
            error = "至少需要识别出四个场地角点后才能另存为球场"; return nil
        }
        let detected = SurveyFieldClassifier.classify(inference)
        let templateID = explicitTemplateID ?? survey.templateID ?? detected.templateID
        guard var spec = templates.first(where: { $0.id == templateID }) else {
            error = "找不到识别出的场地模板"; return nil
        }
        guard let reconstruction = SurveyReconstruction.build(from: survey.points, templateID: templateID) else {
            error = "无法复原这份采点记录"; return nil
        }
        spec = reconstruction.applyingSurveyDimensions(to: spec)
        spec.id = "survey-\(surveyID.uuidString)"
        spec.name = trimmed
        var geometry = FieldGeometry.generate(spec)
        geometry.generationStrategyVersion = 3
        let points = Dictionary(uniqueKeysWithValues: survey.points.map { ($0.id,$0) })
        let cornerNames = ["A","B","C","D"]
        let corners = Dictionary(uniqueKeysWithValues: zip(cornerNames,inference.cornerPointIDs).compactMap { name,id -> (String,LocationSample)? in
            guard let point = points[id] else { return nil }
            return (name,.init(coordinate: point.coordinate, timestamp: point.recordedAt,
                               accuracy: point.horizontalAccuracyMeters))
        })
        do {
            let calibration = try generateMeasuredFieldGeometry(geometry,corners: corners)
            let field = SavedField(name: trimmed,geometry: geometry,calibration: calibration)
            save(field)
            return error == nil ? field.id : nil
        } catch {
            self.error = "四个实测角点无法组成有效球场，请检查识别结果后重试"
            return nil
        }
    }
    /// Existing survey fields with no marking history can be upgraded without
    /// moving their measured corners. Keep fields with sessions unchanged.
    private func upgradeSavedSurveyFields() {
        guard !loadFailed, !surveysLoadFailed else { return }
        var upgraded = fields
        var changed = false
        for index in upgraded.indices {
            var field = upgraded[index]
            guard field.geometry.generationStrategyVersion < 3,
                  field.geometry.spec.id.hasPrefix("survey-"), field.sessions.isEmpty,
                  let surveyID = UUID(uuidString: String(field.geometry.spec.id.dropFirst(7))),
                  let survey = gpsSurveys.first(where: { $0.id == surveyID }),
                  let measured = field.calibration?.measuredCorners,
                  let reconstruction = SurveyReconstruction.build(from: survey.points,
                      templateID: field.geometry.spec.buildOutLines == true ? "7v7" : nil) else { continue }
            let spec = reconstruction.applyingSurveyDimensions(to: field.geometry.spec)
            var geometry = FieldGeometry.generate(spec)
            geometry.generationStrategyVersion = 3
            let accuracy = field.calibration?.accuracy ?? 0
            let corners = Dictionary(uniqueKeysWithValues: measured.map {
                ($0.key, LocationSample(coordinate: $0.value, timestamp: Date(), accuracy: accuracy))
            })
            guard var calibration = try? generateMeasuredFieldGeometry(geometry, corners: corners) else { continue }
            calibration.calibratedAt = field.calibration?.calibratedAt ?? calibration.calibratedAt
            field.geometry = geometry
            field.calibration = calibration
            upgraded[index] = field
            changed = true
        }
        guard changed else { return }
        do {
            try JSONEncoder().encode(upgraded).write(to: url, options: .atomic)
            fields = upgraded
        } catch {
            self.error = "现场采点场地升级失败，原文件未覆盖：\(error.localizedDescription)"
        }
    }
    private func saveSurvey(_ survey: GPSSurvey) -> Bool {
        var next = gpsSurveys
        if let index = next.firstIndex(where: { $0.id == survey.id }) { next[index] = survey }
        else { next.insert(survey, at: 0) }
        return writeSurveys(next)
    }
    private func writeSurveys(_ next: [GPSSurvey]) -> Bool {
        guard !surveysLoadFailed else {
            error = "原 GPS 记录文件无法读取，已阻止覆盖。请先备份并修复本地文件。"; return false
        }
        do {
            try JSONEncoder().encode(next).write(to: surveysURL, options: .atomic)
            gpsSurveys = next
            return true
        } catch {
            self.error = "GPS 记录保存失败：\(error.localizedDescription)"
            return false
        }
    }
    func csvExportURL(for surveyID: UUID) -> URL? {
        guard let survey = gpsSurveys.first(where: { $0.id == surveyID }) else { return nil }
        let file = FileManager.default.temporaryDirectory.appending(path: "FieldLine-GPS-\(survey.id.uuidString).csv")
        do {
            try survey.csv.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            self.error = "CSV 导出失败：\(error.localizedDescription)"
            return nil
        }
    }
    func rawFixesCSVExportURL(for surveyID: UUID) -> URL? {
        guard let survey = gpsSurveys.first(where: { $0.id == surveyID }) else { return nil }
        let file = FileManager.default.temporaryDirectory.appending(path: "FieldLine-GPS-Fixes-\(survey.id.uuidString).csv")
        do {
            try survey.rawFixesCSV.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            self.error = "采样明细 CSV 导出失败：\(error.localizedDescription)"
            return nil
        }
    }
    func segmentsCSVExportURL(for surveyID: UUID) -> URL? {
        guard let survey = gpsSurveys.first(where: { $0.id == surveyID }) else { return nil }
        let file = FileManager.default.temporaryDirectory.appending(path: "FieldLine-Lines-\(survey.id.uuidString).csv")
        do {
            try survey.linesCSV(using: surveyGeometry(survey)).write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            self.error = "线段 CSV 导出失败：\(error.localizedDescription)"
            return nil
        }
    }
    func reconstructionCSVExportURL(for surveyID: UUID) -> URL? {
        guard let survey = gpsSurveys.first(where: { $0.id == surveyID }),
              let reconstruction = SurveyReconstruction.build(from: survey.points, templateID: survey.templateID) else {
            error = "当前采点不足以复原场地"; return nil
        }
        let file = FileManager.default.temporaryDirectory.appending(path: "FieldLine-Reconstruction-\(survey.id.uuidString).csv")
        do {
            try reconstruction.csv.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            self.error = "复原标线 CSV 导出失败：\(error.localizedDescription)"
            return nil
        }
    }
}
@MainActor final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var latest: LocationSample?
    @Published private(set) var latestFix: CLLocation?
    @Published var message = "现场校准时需要定位权限"
    @Published private(set) var lastSamplingMessage: String?
    @Published var sampling = false
    @Published private(set) var samplingSecondsRemaining = 0
    @Published private(set) var samplingTotalSeconds = Int(NavigationThresholds.sampleWindow)
    @Published private(set) var samplingFixCount = 0
    @Published private(set) var bestSamplingAccuracy: Double?
    private let manager = CLLocationManager()
    private var pending: [LocationSample] = []
    private var completion: ((StationaryGPSResult?) -> Void)?
    private var samplingTask: Task<Void, Never>?
    private var samplingStartedAt: Date?
    private var lastRefreshRequest = Date.distantPast
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
    }
    func start() { manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation() }
    func refreshIfStale() {
        guard Date().timeIntervalSince(lastRefreshRequest) >= NavigationThresholds.staleSeconds else { return }
        lastRefreshRequest = Date()
        manager.requestLocation()
    }
    func stop() {
        manager.stopUpdatingLocation()
        samplingTask?.cancel()
        samplingTask = nil
        sampling = false
        samplingSecondsRemaining = 0
        samplingFixCount = 0
        bestSamplingAccuracy = nil
        samplingStartedAt = nil
        completion = nil
        pending = []
    }
    func sample(_ completion: @escaping (LocationSample?) -> Void) {
        sampleDetailed(maximumAccuracy: NavigationThresholds.weakAccuracy, minimumFixes: 3) {
            completion($0?.location)
        }
    }
    func sampleDetailed(maximumAccuracy: Double, minimumFixes: Int = 1,
                        preferredAccuracy: Double? = nil,
                        maximumDuration: Int = Int(NavigationThresholds.sampleWindow),
                        completion: @escaping (StationaryGPSResult?) -> Void) {
        guard !sampling else { return }
        start()
        pending = []
        sampling = true
        samplingTotalSeconds = max(Int(NavigationThresholds.sampleWindow), maximumDuration)
        samplingSecondsRemaining = samplingTotalSeconds
        samplingFixCount = 0
        bestSamplingAccuracy = nil
        samplingStartedAt = Date()
        lastSamplingMessage = nil
        self.completion = completion
        if let latest, abs(latest.timestamp.timeIntervalSinceNow) <= NavigationThresholds.staleSeconds,
           latest.accuracy >= 0 {
            pending.append(latest)
            samplingFixCount = 1
            bestSamplingAccuracy = latest.accuracy
        }
        // A stationary device may not receive another continuous update during
        // sampling. Ask Core Location for a fresh fix while waiting.
        manager.requestLocation()
        samplingTask = Task {
            for elapsed in 1...samplingTotalSeconds {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                samplingSecondsRemaining = samplingTotalSeconds - elapsed
                if elapsed.isMultiple(of: 5) { manager.requestLocation() }
                if elapsed >= Int(NavigationThresholds.sampleWindow),
                   StationaryGPS.aggregate(pending, maximumAccuracy: preferredAccuracy ?? maximumAccuracy,
                                           minimumFixes: minimumFixes) != nil {
                    break
                }
            }
            finishSampling(maximumAccuracy: maximumAccuracy, preferredAccuracy: preferredAccuracy,
                           minimumFixes: minimumFixes)
        }
    }
    private func finishSampling(maximumAccuracy: Double, preferredAccuracy: Double?, minimumFixes: Int) {
        sampling = false
        samplingTask = nil
        samplingStartedAt = nil
        let preferredResult = preferredAccuracy.flatMap {
            StationaryGPS.aggregate(pending, maximumAccuracy: $0, minimumFixes: minimumFixes)
        }
        let result = preferredResult ?? StationaryGPS.aggregate(pending, maximumAccuracy: maximumAccuracy,
                                                                minimumFixes: minimumFixes)
        lastSamplingMessage = result.map {
            if let preferredAccuracy, $0.location.accuracy > preferredAccuracy {
                return "比赛级粗校准 · GPS ±\($0.location.accuracy.formatted(.number.precision(.fractionLength(1)))) m；请结合角间距离检查"
            }
            return $0.acceptedFixes.count >= 3
                ? "采样完成 · \($0.acceptedFixes.count) 个有效定位 · 散布 \($0.spreadMeters.formatted(.number.precision(.fractionLength(1)))) m"
                : "已记录，但只有 \($0.acceptedFixes.count) 个定位，平均效果有限；建议在开阔处重测"
        } ?? {
            if let bestSamplingAccuracy {
                return "本次最佳 GPS ±\(bestSamplingAccuracy.formatted(.number.precision(.fractionLength(1)))) m，未达到 ±\(maximumAccuracy.formatted(.number.precision(.fractionLength(1)))) m；请到开阔处重试"
            }
            return "没有收到新定位，请检查定位权限与精确位置后重试"
        }()
        message = lastSamplingMessage ?? message
        completion?(result)
        completion = nil
        pending = []
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted: message = "定位不可用，请在系统设置中允许使用期间定位并打开精确位置"
        case .authorizedAlways, .authorizedWhenInUse:
            message = manager.accuracyAuthorization == .fullAccuracy ? "正在接收 GPS" : "请在系统设置中开启精确位置"
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where abs(location.timestamp.timeIntervalSinceNow) < NavigationThresholds.staleSeconds && location.horizontalAccuracy >= 0 {
            let sample = LocationSample(coordinate: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), timestamp: location.timestamp, accuracy: location.horizontalAccuracy)
            latest = sample
            latestFix = location
            message = sample.accuracy > NavigationThresholds.weakAccuracy ? "GPS 精度较差，请参考水平精度分析" : "正在接收 GPS"
            if sampling, let samplingStartedAt,
               location.timestamp >= samplingStartedAt.addingTimeInterval(-1) {
                pending.append(sample)
                samplingFixCount = Set(pending.map(\.timestamp)).count
                bestSamplingAccuracy = min(bestSamplingAccuracy ?? sample.accuracy, sample.accuracy)
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown {
            if latest == nil || abs(latest!.timestamp.timeIntervalSinceNow) > NavigationThresholds.staleSeconds {
                message = "等待 GPS 更新"
            }
            return
        }
        message = error.localizedDescription
    }
}
