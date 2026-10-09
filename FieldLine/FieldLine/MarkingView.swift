import SwiftUI
import UIKit

struct MarkingView: View {
    @EnvironmentObject var store: FieldStore
    @Binding var field: SavedField
    let segment: Segment
    let from: String
    let to: String
    @StateObject private var gps = LocationService()
    @State private var engine: NavigationEngine
    @State private var recordedSamples: [LocationSample] = []
    @State private var beganAt: Date?
    @State private var lastNotice = ""
    @State private var confirmFinish = false
    @State private var manualMode: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    init(field: Binding<SavedField>, segment: Segment, from: String, to: String) {
        _field = field; self.segment = segment; self.from = from; self.to = to
        let calibration = field.wrappedValue.calibration!
        _engine = State(initialValue: NavigationEngine(start: calibration.generatedGeoNodes[from]!, end: calibration.generatedGeoNodes[to]!))
        let mismatch = calibration.usesMeasuredBoundary || calibration.usesMeasuredScale ? 0 : anchorDistanceMismatchFraction(field.wrappedValue.geometry,
            firstNode: calibration.anchor1Node, first: calibration.anchor1,
            secondNode: calibration.anchor2Node, second: calibration.candidate)
        _manualMode = State(initialValue: calibration.secondPointIsDirectionOnly == true || calibration.accuracy > NavigationThresholds.weakAccuracy || mismatch > 0.15)
    }
    var position: Point? {
        guard let sample = gps.latest, let c = field.calibration else { return nil }
        return c.fieldPosition(of: sample.coordinate, geometry: field.geometry)
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(manualMode ? (engine.phase == .segmentComplete ? "人工划线完成" : engine.phase == .marking ? "比赛级人工划线中" : "比赛级人工对准") : engine.phase.title)
                    .font(.headline).foregroundStyle(.secondary)
                Text(manualMode ? (engine.phase == .segmentComplete ? "已保存人工记录" : engine.phase == .marking ? "按现场标记划线" : "现场人工对准") : engine.instruction)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(manualMode || engine.gpsWarning ? .orange : .teal).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityAddTraits(.updatesFrequently)
                FieldCanvas(geometry: field.geometry, selected: segment, position: position,
                            positionAccuracy: gps.latest?.accuracy,
                            positionIsStale: gps.latest.map { abs($0.timestamp.timeIntervalSinceNow) > NavigationThresholds.staleSeconds } ?? false)
                    .frame(height: 240)
                Grid(horizontalSpacing: 24, verticalSpacing: 16) {
                    GridRow {
                        metric("横向偏差", manualMode || engine.gpsWarning ? "—" : "\(abs(engine.cross).formatted(.number.precision(.fractionLength(2)))) m \(engine.cross >= 0 ? "右" : "左")")
                        metric("方向误差", manualMode || engine.gpsWarning ? "—" : engine.headingError.map { "\($0.formatted(.number.precision(.fractionLength(1))))°" } ?? "测量中")
                    }
                    GridRow {
                        metric(engine.phase == .returningToStart ? "距离起点" : "终点剩余", manualMode || engine.gpsWarning ? "—" : "\((engine.phase == .returningToStart ? engine.startDistance : engine.remaining).formatted(.number.precision(.fractionLength(1)))) m")
                        metric("GPS 精度", gps.latest.map { "±\($0.accuracy.formatted(.number.precision(.fractionLength(1)))) m" } ?? "等待定位")
                    }
                }
                if manualMode {
                    Text("比赛级人工模式：GPS 仅显示大致位置。请用现场角点、边线和距离标记确认方向与终点；App 不提供米级纠偏或终点提醒。")
                        .foregroundStyle(.orange)
                } else if engine.gpsWarning {
                    Text("定位不可靠或已过期，请暂停喷漆并等待信号恢复，或切换人工对准。")
                        .foregroundStyle(.orange)
                }
                if !manualMode && !engine.gpsWarning && engine.phase == .marking {
                    if engine.remaining <= NavigationThresholds.closeEnd { Text("到达终点附近 · 准备停止喷漆").foregroundStyle(.orange) }
                    else if engine.remaining <= NavigationThresholds.nearEnd { Text("距终点不足 5 m").foregroundStyle(.orange) }
                    if abs(engine.cross) >= NavigationThresholds.majorCrossTrack { Text("偏差较大，请暂停并重新检查路线").foregroundStyle(.orange) }
                }
                controls
                Text(gps.message).font(.caption).foregroundStyle(.secondary)
                Text("保持 App 在前台。所有提示来自手机 GPS，仅供原型实测；手动控制喷漆。").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("\(from) → \(to)").navigationBarTitleDisplayMode(.inline)
            .onAppear { gps.start(); UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onReceive(gps.$latest) { sample in
                guard let sample else { return }
                engine.update(sample)
                if engine.phase == .marking && (manualMode || !engine.gpsWarning) { recordedSamples.append(sample) }
                let notice = engine.gpsWarning ? "weak" : engine.remaining <= 0 ? "end" : engine.remaining <= 2 ? "2m" : engine.remaining <= 5 ? "5m" : "far"
                if !manualMode && engine.phase == .marking && notice != lastNotice {
                    UINotificationFeedbackGenerator().notificationOccurred(notice == "weak" ? .warning : .success)
                    lastNotice = notice
                }
            }
            .onReceive(timer) { now in
                if gps.latest == nil || now.timeIntervalSince(gps.latest!.timestamp) > NavigationThresholds.staleSeconds {
                    engine.gpsWarning = true; engine.stableSince = nil; engine.headingError = nil; engine.samples = []
                }
            }
            .confirmationDialog("确认已关闭喷漆并完成该线段？", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("已关闭喷漆，保存记录") { finish() }
                Button("继续", role: .cancel) {}
            }
    }
    func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder var controls: some View {
        if manualMode {
            switch engine.phase {
            case .marking:
                Button("结束线段 · 关闭喷漆") { confirmFinish = true }
                    .buttonStyle(.borderedProminent)
            case .segmentComplete:
                Label("人工划线记录已保存", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.teal)
            default:
                Text("将车放在现场确认的起点，目视对准终点。准备好后手动开启喷漆。")
                Button("已在起点并对准 · 开始划线") {
                    beganAt = Date(); recordedSamples = []; engine.phase = .marking
                }.buttonStyle(.borderedProminent)
                Button("返回 GPS 导航") { manualMode = false; engine.beginCalibration() }
            }
        } else {
            switch engine.phase {
            case .lineSelected:
                Text("将车放在线段起点，关闭喷漆，向前推行至少 4 m 测量方向。")
                Button("开始方向校准") { engine.beginCalibration() }.buttonStyle(.borderedProminent).disabled(engine.gpsWarning)
            case .calibratingDirection:
                Text("不开喷，继续向前推行。方向需在 ±5° 内保持 2 秒。")
                Button("重新测量") { engine.beginCalibration() }
            case .aligned:
                Text("保持车轮方向不变，倒回起点。")
                Button("开始倒回起点") { engine.phase = .returningToStart }.buttonStyle(.borderedProminent).disabled(engine.gpsWarning)
            case .returningToStart:
                Text("不开喷，倒回起点 1.5 m 范围内。")
            case .readyToMark:
                Button("手动开启喷漆并开始划线") {
                    guard !engine.gpsWarning && engine.startDistance <= NavigationThresholds.readyDistance else { return }
                    beganAt = Date(); recordedSamples = []; engine.phase = .marking
                }.buttonStyle(.borderedProminent).disabled(engine.gpsWarning)
            case .marking:
                Button("结束线段 · 关闭喷漆") { confirmFinish = true }.buttonStyle(.borderedProminent)
            case .segmentComplete:
                Label("记录已保存", systemImage: "checkmark.circle.fill").foregroundStyle(.teal)
            }
            if engine.phase != .marking && engine.phase != .segmentComplete {
                Button("比赛级人工对准 · 不依赖 GPS") { manualMode = true }
                    .buttonStyle(.bordered)
            }
        }
    }
    func finish() {
        let errors = manualMode ? [] : recordedSamples.map { abs(Geo.project($0.coordinate, start: engine.start, end: engine.end).cross) }
        let record = MarkingRecord(segmentID: "\(from) → \(to)", startTime: beganAt ?? Date(), endTime: Date(), samples: recordedSamples,
                                   maxCrossTrackError: errors.max() ?? 0, averageCrossTrackError: errors.isEmpty ? 0 : errors.reduce(0, +)/Double(errors.count),
                                   manuallyGuided: manualMode)
        field.sessions.append(record); store.save(field)
        if store.error == nil { engine.phase = .segmentComplete }
        else { field.sessions.removeLast() }
    }
}
