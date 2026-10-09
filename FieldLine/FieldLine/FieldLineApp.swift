import SwiftUI

@main struct FieldLineApp: App {
    @StateObject private var store = FieldStore()
    var body: some Scene {
        WindowGroup { HomeView().environmentObject(store).tint(.teal) }
    }
}
struct HomeView: View {
    @EnvironmentObject var store: FieldStore
    @State private var creating = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("FIELDLINE", systemImage: "sportscourt.fill").font(.headline).foregroundStyle(.teal)
                        Text("从一个角点，\n开始一座球场。").font(.largeTitle.bold())
                        Text("智能足球场划线助手").foregroundStyle(.secondary)
                        Button { creating = true } label: {
                            ZStack {
                                Text("新建场地")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(colors: [Color(red: 0.04, green: 0.68, blue: 0.65),
                                                        Color(red: 0.02, green: 0.52, blue: 0.50)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: .teal.opacity(0.18), radius: 7, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("新建场地")
                        .padding(.top, 8)
                    }.padding(.vertical, 14)
                }
                Section("辅助工具") {
                    NavigationLink {
                        GoalPlacementView()
                    } label: {
                        Label("球门放置", systemImage: "scope")
                    }
                    NavigationLink {
                        GPSLogsView()
                    } label: {
                        Label("GPS 采点与距离分析", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }
                Section("我的场地") {
                    if store.fields.isEmpty { Text("还没有场地。选择模板，预览并保存你的第一个球场。").foregroundStyle(.secondary) }
                    ForEach(store.fields) { field in
                        NavigationLink { FieldDetailView(field: field) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(field.name).font(.headline)
                                Text("\(field.geometry.spec.name) · \(field.geometry.spec.length.formatted(.number.precision(.fractionLength(1)))) × \(field.geometry.spec.width.formatted(.number.precision(.fractionLength(1)))) m").font(.subheadline)
                                Text(field.calibration == nil ? "待现场校准" : "已校准 · \(field.sessions.count) 次划线记录").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 5)
                        }
                    }
                }
                Section { Text("原型版本 · GPS 精度需草坪实测。App 仅提供辅助提示，喷漆与推车均由人操作。").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("FieldLine")
                .sheet(isPresented: $creating) { NewFieldView() }
                .alert("存储提示", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("好") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
}
struct NewFieldView: View {
    @EnvironmentObject var store: FieldStore
    @Environment(\.dismiss) var dismiss
    @State private var templateID = "7v7"
    @State private var name = ""
    @State private var length = "90"
    @State private var width = "60"
    private var savedField: SavedField? {
        guard templateID.hasPrefix("saved:"), let id = UUID(uuidString: String(templateID.dropFirst(6))) else { return nil }
        return store.fields.first { $0.id == id }
    }
    var validSize: Bool {
        guard let l = Double(length), let w = Double(width) else { return false }
        return l.isFinite && w.isFinite && (20...150).contains(l) && (15...100).contains(w) && l >= w
    }
    var spec: TemplateSpec? {
        if let savedField { return savedField.geometry.spec }
        if templateID == "custom" {
            return validSize ? .custom(length: Double(length)!,width: Double(width)!) : nil
        }
        return store.templates.first { $0.id == templateID }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("选择模板") {
                    Picker("类型", selection: $templateID) {
                        ForEach(store.templates) { Text($0.name).tag($0.id) }
                        if !store.fields.isEmpty {
                            Section("已保存场地") {
                                ForEach(store.fields) { Text($0.name).tag("saved:\($0.id.uuidString)") }
                            }
                        }
                        Text("Custom").tag("custom")
                    }.pickerStyle(.menu)
                    if templateID == "custom" {
                        TextField("长度（米）", text: $length).keyboardType(.decimalPad)
                        TextField("宽度（米）", text: $width).keyboardType(.decimalPad)
                        Text("长度 20–150 m，宽度 15–100 m，长度不得小于宽度。内部线按比例生成。").font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("场地名称", text: $name)
                }
                if let spec {
                    Section("场地预览") {
                        FieldCanvas(geometry: .generate(spec)).frame(height: 340)
                        Text("\(spec.length.formatted()) × \(spec.width.formatted()) m · 原型尺寸配置").font(.caption)
                        if savedField != nil {
                            Text("来自已保存的现场球场；创建后保留采集坐标与放缩校准，可直接使用。")
                                .font(.caption).foregroundStyle(.mint)
                        }
                        if spec.buildOutLines == true {
                            Text("7v7：无小禁区；两条回撤线位于禁区前沿与中线的中间。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("直线导航支持外框、半场线及禁区线；圆与弧线显示在图中，当前需人工完成。").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("保存场地，准备现场校准") {
                        guard let spec else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.save(.init(name: trimmed.isEmpty ? "\(spec.name) Field" : trimmed,
                                         geometry: savedField?.geometry ?? .generate(spec),
                                         calibration: savedField?.calibration))
                        if store.error == nil { dismiss() }
                    }.disabled(spec == nil)
                }
            }.navigationTitle("新建场地")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}
struct FieldDetailView: View {
    @EnvironmentObject var store: FieldStore
    @State var field: SavedField
    @State private var calibrating = false
    @StateObject private var gps = LocationService()
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var currentFix: LocationSample? {
        guard field.calibration != nil, let fix = gps.latest, fix.accuracy >= 0 else { return nil }
        return fix
    }
    private var currentFixIsStale: Bool {
        guard let currentFix else { return false }
        return abs(now.timeIntervalSince(currentFix.timestamp)) > NavigationThresholds.staleSeconds
    }
    private var currentFieldPosition: Point? {
        guard let calibration = field.calibration, let currentFix else { return nil }
        return calibration.fieldPosition(of: currentFix.coordinate, geometry: field.geometry)
    }
    private var measuredCorners: Set<String> {
        guard let calibration = field.calibration else { return [] }
        if calibration.usesMeasuredBoundary { return ["A", "B", "C", "D"] }
        return calibration.secondPointIsDirectionOnly == true
            ? [calibration.anchor1Node]
            : [calibration.anchor1Node, calibration.anchor2Node]
    }
    private var inferredCorners: Set<String> {
        guard let calibration = field.calibration, calibration.secondPointIsDirectionOnly == true else { return [] }
        return [calibration.anchor2Node]
    }
    private var directionMarker: Point? {
        guard let calibration = field.calibration, calibration.secondPointIsDirectionOnly == true else { return nil }
        return calibration.fieldPosition(of: calibration.candidate, geometry: field.geometry)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FieldCanvas(geometry: field.geometry, position: currentFieldPosition,
                            positionAccuracy: currentFix?.accuracy,
                            positionIsStale: currentFixIsStale,
                            markedCorners: measuredCorners,
                            inferredCorners: inferredCorners,
                            directionMarker: directionMarker)
                    .frame(height: 390)
                Text("\(field.geometry.spec.name) · \(field.geometry.spec.length.formatted(.number.precision(.fractionLength(1)))) × \(field.geometry.spec.width.formatted(.number.precision(.fractionLength(1)))) m").font(.title3.bold())
                if let calibration = field.calibration {
                    let mismatch = anchorDistanceMismatchFraction(field.geometry,
                        firstNode: calibration.anchor1Node, first: calibration.anchor1,
                        secondNode: calibration.anchor2Node, second: calibration.candidate)
                    let directionOnly = calibration.secondPointIsDirectionOnly == true
                    let measuredBoundary = calibration.usesMeasuredBoundary
                    let measuredScale = calibration.usesMeasuredScale
                    let roughCalibration = directionOnly || calibration.accuracy > NavigationThresholds.weakAccuracy || (!measuredBoundary && !measuredScale && mismatch > 0.15)
                    Label(measuredBoundary ? "已按四个实测角放缩匹配" : measuredScale ? "已使用实测点等比例缩放" : directionOnly ? "已按方向点延伸到标准角" : roughCalibration ? "已保存比赛级粗校准" : "已保存现场校准",
                          systemImage: roughCalibration ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(roughCalibration ? .orange : .teal)
                    Text(measuredBoundary
                         ? "A、B、C、D 均为现场实测点 · GPS ±\(calibration.accuracy.formatted(.number.precision(.fractionLength(1)))) m"
                         : measuredScale
                         ? "A → B 实测 \(Geo.distanceMeters(calibration.anchor1, calibration.candidate).formatted(.number.precision(.fractionLength(1)))) m · 模板缩放为 \(((calibration.measuredScale ?? 1) * 100).formatted(.number.precision(.fractionLength(1))))% · GPS ±\(calibration.accuracy.formatted(.number.precision(.fractionLength(1)))) m"
                         : directionOnly
                         ? "\(calibration.anchor1Node) → 方向点 \(Geo.distanceMeters(calibration.anchor1, calibration.candidate).formatted(.number.precision(.fractionLength(1)))) m → 推算 \(calibration.anchor2Node) · GPS ±\(calibration.accuracy.formatted(.number.precision(.fractionLength(1)))) m"
                         : "\(calibration.anchor1Node) → \(calibration.anchor2Node) · GPS ±\(calibration.accuracy.formatted(.number.precision(.fractionLength(1)))) m · 角间差 \((mismatch * 100).formatted(.number.precision(.fractionLength(1))))%")
                        .font(.caption)
                    if measuredBoundary {
                        Text(field.geometry.spec.id.hasPrefix("survey-")
                             ? "四个外角取自现场采点；已识别的禁区和点球点采用采点复原尺寸，另一端镜像补全。未识别的标线沿用模板。"
                             : "模板只提供各条标线的相对位置；最终边界使用现场采集四点，内部线随四边放缩匹配。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if measuredScale {
                        Text("A、B 两个实测点保持不变；长度、宽度和内部标线沿用标准模板比例并统一缩放。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if roughCalibration {
                        Text(directionOnly
                             ? "橙点是实测方向点，橙圈“推”是按模板长度延伸的位置；请在现场核对终点。"
                             : "适合查看整体位置；靠近边线和禁区时请以现场标记核对。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let currentFieldPosition, let currentFix {
                        let inside = (0...field.geometry.spec.width).contains(currentFieldPosition.x) &&
                            (0...field.geometry.spec.length).contains(currentFieldPosition.y)
                        Label(currentFixIsStale ? "等待新定位，图上为上次位置" :
                              inside ? "你在场地范围内（估算）" : "你在场地范围外或定位偏移（估算）",
                              systemImage: currentFixIsStale ? "clock" : "location.fill")
                            .foregroundStyle(currentFixIsStale || currentFix.accuracy > NavigationThresholds.weakAccuracy ? .orange : .teal)
                        Text("距左边约 \(currentFieldPosition.x.formatted(.number.precision(.fractionLength(1)))) m · 距 A–B 端约 \(currentFieldPosition.y.formatted(.number.precision(.fractionLength(1)))) m · GPS ±\(currentFix.accuracy.formatted(.number.precision(.fractionLength(1)))) m")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("正在等待当前位置；取得新定位后会在图上显示“你”。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    NavigationLink { ChooseSegmentView(field: $field) } label: { Label("开始划线", systemImage: "location.north.line.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                }
                Button(field.calibration == nil ? "Set Up Field · 现场校准" : "重新校准场地") { calibrating = true }.buttonStyle(.bordered)
                Text("每次使用前确认角点仍与草坪标记重合。手机 GPS 的精度不代表喷线精度。").font(.footnote).foregroundStyle(.secondary)
                if !field.sessions.isEmpty {
                    Text("划线记录").font(.headline)
                    ForEach(field.sessions.reversed()) { record in
                        VStack(alignment: .leading) {
                            Text(record.segmentID).bold()
                            Text(record.endTime.formatted(date: .abbreviated, time: .shortened))
                            Text(record.manuallyGuided == true
                                 ? "人工对准记录 · GPS 轨迹仅供参考"
                                 : "平均横偏 \(record.averageCrossTrackError.formatted(.number.precision(.fractionLength(2)))) m · 最大 \(record.maxCrossTrackError.formatted(.number.precision(.fractionLength(2)))) m")
                                .font(.caption)
                        }
                    }
                }
            }.padding()
        }.navigationTitle(field.name)
            .onAppear { if field.calibration != nil { gps.start() } }
            .onDisappear { gps.stop() }
            .onReceive(ticker) {
                now = $0
                if field.calibration != nil && (gps.latest == nil || currentFixIsStale) {
                    gps.refreshIfStale()
                }
            }
            .onChange(of: field.calibration != nil) { _, calibrated in
                if calibrated { gps.start() }
            }
            .sheet(isPresented: $calibrating) {
                AnchorView(geometry: field.geometry) { calibration in
                    var updated = field
                    updated.calibration = calibration
                    store.save(updated)
                    guard store.error == nil else { return false }
                    field = updated
                    gps.start()
                    return true
                }
            }
    }
}
struct AnchorView: View {
    private struct PendingAnchorChoice {
        let sample: LocationSample
        let assessment: SecondAnchorAssessment
    }
    let geometry: FieldGeometry
    var onSave: (Calibration) -> Bool
    @Environment(\.dismiss) var dismiss
    @StateObject private var gps = LocationService()
    @State private var samples: [String: LocationSample] = [:]
    @State private var currentCorner = "A"
    @State private var result: Calibration?
    @State private var error: String?
    @State private var pendingAnchorChoice: PendingAnchorChoice?
    @State private var showAnchorChoice = false
    private let cornerOrder = ["A", "B", "C", "D"]
    private var currentPosition: Point? {
        guard let result, let latest = gps.latest,
              latest.accuracy >= 0,
              abs(latest.timestamp.timeIntervalSinceNow) <= NavigationThresholds.staleSeconds else { return nil }
        return result.fieldPosition(of: latest.coordinate, geometry: geometry)
    }
    private var measuredCorners: Set<String> { Set(samples.keys) }
    private func edge(_ first: String, _ second: String) -> Double? {
        guard let a = samples[first], let b = samples[second] else { return nil }
        return Geo.distanceMeters(a.coordinate, b.coordinate)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FieldCanvas(geometry: geometry, position: currentPosition,
                                positionAccuracy: gps.latest?.accuracy,
                                markedCorners: measuredCorners)
                        .frame(height: 300)
                    Text(result == nil
                         ? "依次走到现场 A、B、C、D 四个角并记录。每个实测点都会保留，不会按模板长度延伸。"
                         : result?.usesMeasuredScale == true
                         ? "已采用当前实测 B 点，并按 A–B 实测距离等比例缩放整套标准场地。"
                         : result?.usesMeasuredBoundary == true
                         ? "四个现场角点已保存。标准场地的边线和内部标线已按比例贴合实测边界。"
                         : "已按标准尺寸从实测方向延伸到目标角。")
                        .font(.subheadline)
                    if result == nil {
                        Text("当前记录 \(currentCorner) 角 · 已完成 \(samples.count)/4。优先等待 GPS 达到 ±5 m，最多采样 20 秒。")
                            .font(.caption).foregroundStyle(.secondary)
                        if gps.sampling {
                            HStack {
                                Text("\(gps.samplingSecondsRemaining)").font(.largeTitle.bold().monospacedDigit())
                                Text("秒 · 请站稳")
                            }
                            ProgressView(value: Double(gps.samplingTotalSeconds - gps.samplingSecondsRemaining),
                                         total: Double(gps.samplingTotalSeconds))
                            Text("已收到 \(gps.samplingFixCount) 个定位更新\(gps.bestSamplingAccuracy.map { " · 最佳 ±\($0.formatted(.number.precision(.fractionLength(1)))) m" } ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button(gps.sampling ? "正在采样…" : "Set Point · 记录 \(currentCorner) 角") { captureCorner() }
                            .disabled(gps.sampling || gps.latest == nil)
                    }
                    Text(gps.lastSamplingMessage ?? gps.message).font(.caption)
                    if let latest = gps.latest {
                        Text("当前 GPS ±\(latest.accuracy.formatted(.number.precision(.fractionLength(1)))) m\(latest.accuracy > NavigationThresholds.clubAnchorMaximumAccuracy ? " · 超出可用范围" : latest.accuracy > NavigationThresholds.weakAccuracy ? " · 可作比赛级粗校准" : "")")
                            .font(.caption)
                            .foregroundStyle(latest.accuracy > NavigationThresholds.weakAccuracy ? .orange : .secondary)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                if !samples.isEmpty {
                    Section("现场采集点") {
                        ForEach(cornerOrder.filter { samples[$0] != nil }, id: \.self) { corner in
                            Label("\(corner) 角已实测", systemImage: "checkmark.circle.fill").foregroundStyle(.teal)
                        }
                        if let ab = edge("A", "B") { LabeledContent("A–B 实测", value: "\(ab.formatted(.number.precision(.fractionLength(1)))) m") }
                        if let bc = edge("B", "C") { LabeledContent("B–C 实测", value: "\(bc.formatted(.number.precision(.fractionLength(1)))) m") }
                        if let cd = edge("C", "D") { LabeledContent("C–D 实测", value: "\(cd.formatted(.number.precision(.fractionLength(1)))) m") }
                        if let da = edge("D", "A") { LabeledContent("D–A 实测", value: "\(da.formatted(.number.precision(.fractionLength(1)))) m") }
                        Text("标准模板 \(geometry.spec.length.formatted()) × \(geometry.spec.width.formatted()) m 只提供线条比例；现场四角决定最终边界。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if result != nil {
                    Section("校准完成") {
                        Label(result?.usesMeasuredScale == true ? "已使用现有采集点坐标" : result?.usesMeasuredBoundary == true ? "已采用 A、B、C、D 四个实测点" : "已按标准尺寸延伸",
                              systemImage: "checkmark.circle.fill").foregroundStyle(.teal)
                        Text(result?.usesMeasuredScale == true
                             ? "当前实测点保持不变；标准模板的长度、宽度和内部标线统一按比例缩放。"
                             : result?.usesMeasuredBoundary == true
                             ? "所有内部标线使用标准模板中的相对位置，沿现场宽度和长度方向放缩匹配。四个角不会被移动或延长。"
                             : "目标角和其他标线使用标准模板尺寸推算。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("查看实时场地地图") { dismiss() }.buttonStyle(.borderedProminent)
                    }
                }
                if !samples.isEmpty {
                    Button("重新采集 A、B、C、D") {
                        samples = [:]; currentCorner = "A"; result = nil; error = nil
                    }.disabled(gps.sampling)
                }
            }
            .navigationTitle(result == nil ? "记录 \(currentCorner) 角" : "校准成功")
            .toolbar { Button("关闭") { dismiss() } }
            .onAppear { gps.start() }
            .onDisappear { gps.stop() }
            .alert("按标准尺寸延伸到 B 角？", isPresented: $showAnchorChoice) {
                Button("自动延伸到标准角") { savePendingAnchor(useMeasuredCoordinate: false) }
                Button("使用现有采集点坐标") { savePendingAnchor(useMeasuredCoordinate: true) }
                Button("重新采样", role: .cancel) { pendingAnchorChoice = nil }
            } message: {
                if let pendingAnchorChoice {
                    Text("实测 A–B 为 \(pendingAnchorChoice.assessment.measuredDistance.formatted(.number.precision(.fractionLength(1)))) m，模板角间距为 \(pendingAnchorChoice.assessment.templateDistance.formatted(.number.precision(.fractionLength(1)))) m。可按标准尺寸延伸，也可保留当前实测 B 点并等比例缩放整套场地。")
                }
            }
        }
    }
    private func captureCorner() {
        let selectedCorner = currentCorner
        gps.sampleDetailed(maximumAccuracy: NavigationThresholds.clubAnchorMaximumAccuracy,
                           preferredAccuracy: NavigationThresholds.weakAccuracy,
                           maximumDuration: NavigationThresholds.anchorMaximumDuration) { sampled in
            guard let sampled else {
                error = gps.lastSamplingMessage ?? "定位采样失败，请站稳重试。"
                return
            }
            if selectedCorner == "B", let first = samples["A"] {
                let assessment = assessSecondAnchor(geometry, firstNode: "A", first: first.coordinate,
                                                    secondNode: "B", second: sampled.location.coordinate)
                if assessment.decision != .measuredCorner {
                    pendingAnchorChoice = .init(sample: sampled.location, assessment: assessment)
                    showAnchorChoice = true
                    error = nil
                    return
                }
            }
            samples[selectedCorner] = sampled.location
            error = nil
            guard samples.count == cornerOrder.count else {
                currentCorner = cornerOrder.first { samples[$0] == nil } ?? "A"
                return
            }
            do {
                let calibration = try generateMeasuredFieldGeometry(geometry, corners: samples)
                guard onSave(calibration) else {
                    error = "校准结果未能保存，请检查存储提示后重试。"
                    return
                }
                result = calibration
            } catch {
                samples[selectedCorner] = nil
                currentCorner = selectedCorner
                self.error = "四个点无法组成有效场地边界。请确认按 A → B → C → D 沿场地四周依次采集，然后重新记录 \(selectedCorner) 角。"
            }
        }
    }
    private func savePendingAnchor(useMeasuredCoordinate: Bool) {
        guard let first = samples["A"], let pendingAnchorChoice else { return }
        do {
            let calibration: Calibration
            if useMeasuredCoordinate {
                calibration = try generateScaledFieldGeometry(geometry, anchor1Node: "A", anchor1: first.coordinate,
                                                               anchor2Node: "B", measuredAnchor2: pendingAnchorChoice.sample.coordinate,
                                                               accuracy: max(first.accuracy, pendingAnchorChoice.sample.accuracy))
            } else {
                var standard = try generateFieldGeometry(geometry, anchor1Node: "A", anchor1: first.coordinate,
                                                         anchor2Node: "B", candidate: pendingAnchorChoice.sample.coordinate,
                                                         accuracy: max(first.accuracy, pendingAnchorChoice.sample.accuracy))
                standard.secondPointIsDirectionOnly = true
                calibration = standard
            }
            guard onSave(calibration) else {
                error = "校准结果未能保存，请检查存储提示后重试。"
                return
            }
            samples["B"] = pendingAnchorChoice.sample
            result = calibration
            self.pendingAnchorChoice = nil
            error = nil
        } catch {
            self.error = "两个采样点太近，无法放缩匹配；请重新采样 B 角。"
            self.pendingAnchorChoice = nil
        }
    }
}
struct ChooseSegmentView: View {
    @Binding var field: SavedField
    @State private var node = "A"
    var starts: [String] { field.geometry.nodes.map(\.id).filter { !field.geometry.connectedSegments($0).isEmpty } }
    var body: some View {
        List {
            Section { FieldCanvas(geometry: field.geometry).frame(height: 280) }
            Section("当前起点") { Picker("节点", selection: $node) { ForEach(starts, id: \.self) { Text($0).tag($0) } } }
            Section("相连的合法目标") {
                ForEach(field.geometry.connectedSegments(node)) { segment in
                    let target = segment.from == node ? segment.to : segment.from
                    NavigationLink("\(node) → \(target)") {
                        MarkingView(field: $field, segment: segment, from: node, to: target)
                    }
                }
            }
        }.navigationTitle("选择线段")
    }
}
