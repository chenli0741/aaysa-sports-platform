import SwiftUI
import CoreLocation
import UIKit

struct GPSLogsView: View {
    @EnvironmentObject private var store: FieldStore
    @State private var newSurveyID: UUID?
    @State private var editingSurvey: GPSSurvey?
    @State private var editedName = ""
    @State private var pendingDelete: GPSSurvey?

    var body: some View {
        List {
            Section {
                Button("新建采点记录", systemImage: "plus.circle.fill") {
                    if let id = store.createGPSSurvey() {
                        newSurveyID = id
                    }
                }.font(.headline)
                Text("到现场后，打开记录并逐点点击“记录当前位置”。坐标和 GPS 精度会保存到本机。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("已保存的记录") {
                if store.gpsSurveys.isEmpty {
                    Text("暂无采点记录").foregroundStyle(.secondary)
                }
                ForEach(store.gpsSurveys) { survey in
                    NavigationLink {
                        GPSCaptureView(surveyID: survey.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(survey.name).font(.headline)
                            Text("\(survey.points.count) 个点 · \(SurveyReconstruction.build(from: survey.points, templateID: survey.templateID)?.lines.count ?? survey.lines(using: store.surveyGeometry(survey)).count) 条线")
                                .font(.subheadline)
                            Text(survey.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("编辑", systemImage: "pencil") {
                            editedName = survey.name
                            editingSurvey = survey
                        }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            pendingDelete = survey
                        }
                    }
                }
            }
        }
        .navigationTitle("GPS 采点")
        .navigationDestination(item: $newSurveyID) { id in
            GPSCaptureView(surveyID: id)
        }
        .sheet(item: $editingSurvey) { survey in
            NavigationStack {
                Form {
                    TextField("记录名称", text: $editedName)
                    Text("修改名称不会改变采点坐标、时间或距离。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .navigationTitle("编辑记录")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { editingSurvey = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if store.renameGPSSurvey(survey.id, to: editedName) { editingSurvey = nil }
                        }.disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("删除“\(pendingDelete?.name ?? "记录")”及全部采点？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                if let survey = pendingDelete { store.deleteGPSSurvey(survey.id) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }
}

struct GPSCaptureView: View {
    @EnvironmentObject private var store: FieldStore
    @StateObject private var gps = LocationService()
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var startPointID: UUID?
    @State private var endPointID: UUID?
    @State private var captureNodeID = ""
    @State private var showSaveField = false
    @State private var fieldName = ""
    @State private var savedFieldMessage: String?
    let surveyID: UUID

    private var survey: GPSSurvey? { store.gpsSurveys.first { $0.id == surveyID } }
    private var canCaptureNode: Bool {
        guard !captureNodeID.isEmpty else { return true }
        guard let survey, let geometry = store.surveyGeometry(survey) else { return false }
        return geometry.nodes.contains { $0.id == captureNodeID } &&
            !survey.points.contains { $0.fieldNodeID == captureNodeID }
    }
    private var canAddSegment: Bool {
        guard let survey, let startPointID, let endPointID else { return false }
        return startPointID != endPointID &&
            survey.distanceMeters(from: startPointID, to: endPointID) != nil &&
            !survey.lines(using: store.surveyGeometry(survey)).contains {
                ($0.fromPointID == startPointID && $0.toPointID == endPointID) ||
                ($0.fromPointID == endPointID && $0.toPointID == startPointID)
            }
    }
    private var usableFix: CLLocation? {
        guard let fix = gps.latestFix,
              fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) <= NavigationThresholds.staleSeconds else { return nil }
        return fix
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let survey {
                    let rawInference = SurveyInference.suggest(for: survey.points)
                    let classification = rawInference.map(SurveyFieldClassifier.classify)
                    let effectiveTemplateID = survey.templateID ?? classification?.templateID
                    let geometry = effectiveTemplateID.flatMap { id in store.templates.first(where: { $0.id == id }).map(FieldGeometry.generate) }
                    let lines = survey.lines(using: geometry)
                    let reconstruction = SurveyReconstruction.build(from: survey.points, templateID: effectiveTemplateID)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(survey.name).font(.title2.bold())
                        Text("\(survey.points.count) 个采点 · \(reconstruction?.lines.count ?? lines.count) 条场地线")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Picker("场地结构", selection: Binding(
                        get: { self.survey?.templateID ?? "auto" },
                        set: { store.setGPSSurveyTemplate(surveyID, to: $0 == "auto" ? nil : $0); captureNodeID = "" }
                    )) {
                        Text("自动识别").tag("auto")
                        ForEach(store.templates) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(gps.sampling)
                    if let classification {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(survey.templateID == nil ? "自动识别：\(classification.title)" : "识别建议：\(classification.title)",
                                  systemImage: classification.templateID == "7v7" ? "arrow.left.and.right" : "sportscourt")
                                .font(.headline)
                            Text("置信度 \((classification.confidence*100).formatted(.number.precision(.fractionLength(0))))% · \(classification.reason)")
                                .font(.caption).foregroundStyle(.secondary)
                            if survey.templateID != nil, survey.templateID != classification.templateID {
                                Text("当前人工选择与识别建议不同；保存前请核对场地标线。")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity,alignment: .leading)
                        .background(.regularMaterial,in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let reconstruction {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("实时复原 · 每次采点后更新").font(.headline)
                            Text("外框约 \(reconstruction.inference.lengthMeters.formatted(.number.precision(.fractionLength(1)))) × \(reconstruction.inference.widthMeters.formatted(.number.precision(.fractionLength(1)))) m；四角为点 \(reconstruction.inference.cornerPointIDs.compactMap { survey.pointNumber(for: $0) }.map(String.init).joined(separator: "、"))。")
                                .font(.subheadline)
                            Text(effectiveTemplateID == "7v7"
                                 ? (reconstruction.inference.penaltyFrontPointIDs.isEmpty
                                    ? "已补外框和中线；继续采禁区前沿两个角，识别后会补禁区与球门球回撤线。"
                                    : reconstruction.inference.penaltySpotPointID == nil
                                    ? "已补两端禁区和球门球回撤线；继续采点球点。"
                                    : "外框、中线、两端禁区、球门球回撤线和点球点已复原；新增采点仍会重新计算。")
                                 : reconstruction.inference.penaltyFrontPointIDs.isEmpty
                                 ? "已补外框和中线；继续采禁区前沿两个角，识别后会立即补齐两端禁区。"
                                 : reconstruction.inference.goalFrontPointIDs.isEmpty
                                 ? "已补两端禁区；继续采球门区前沿两个角。"
                                 : reconstruction.inference.penaltySpotPointID == nil
                                 ? "已补两端禁区和球门区；继续采点球点。"
                                 : "外框、中线、两端禁区、球门区和点球点已复原；新增采点仍会重新计算。")
                                .font(.subheadline).foregroundStyle(.mint)
                            if !reconstruction.inference.penaltyFrontPointIDs.isEmpty {
                                Text("禁区前角：点 \(reconstruction.inference.penaltyFrontPointIDs.compactMap { survey.pointNumber(for: $0) }.map(String.init).joined(separator: "、"))；\(effectiveTemplateID == "7v7" ? "球门球回撤线按禁区与中线推算" : "球门区前角：点 \(reconstruction.inference.goalFrontPointIDs.compactMap { survey.pointNumber(for: $0) }.map(String.init).joined(separator: "、"))")；点球点：\(reconstruction.inference.penaltySpotPointID.flatMap { survey.pointNumber(for: $0) }.map { "点 \($0)" } ?? "未识别")。")
                                    .font(.subheadline)
                            }
                            Text("画布按场地长边对正以便看清标注。橙点是原始 GPS，只给关键点标号，全部点号在下方列表。实线按采点拟合，虚线是另一端镜像补线；原始坐标没有改动。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("实时复原：继续采场地外框。识别出四角后会先补全外框和中线，后续每识别一组内部标记就立即补线。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    GPSPointsCanvas(points: survey.points, lines: reconstruction == nil ? lines : lines.filter { !$0.isAutomatic }, reconstruction: reconstruction)
                        .frame(height: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    Text(reconstruction == nil
                         ? "采点顺序不参与连线。若点位不足以识别场地，可继续采点、标注场地位置，或手动补画线。"
                         : "线上的米数是复原几何的估算值；橙色原始点保留供核对。镜像线与居中位置是推算，不是独立 GPS 实测。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if reconstruction != nil, let effectiveTemplateID {
                        Button("另存为球场", systemImage: "square.and.arrow.down") {
                            fieldName = survey.name
                            showSaveField = true
                        }
                        .buttonStyle(.borderedProminent)
                        Text("另存后会出现在首页场地列表，也会显示在“新建场地”的已保存场地中，可直接复用现场坐标。当前类型：\(store.templates.first(where: { $0.id == effectiveTemplateID })?.name ?? effectiveTemplateID)。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if geometry != nil {
                        Text("模板中的 A–B 为一端球门线，C–D 为另一端；禁区角按底线左端、前沿左角、前沿右角、底线右端选择。已采的点也可在下方补标或改标。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("当前 GPS", systemImage: "location.fill").font(.headline)
                        if let fix = usableFix {
                            Text("\(fix.coordinate.latitude.formatted(.number.precision(.fractionLength(7))))°, \(fix.coordinate.longitude.formatted(.number.precision(.fractionLength(7))))°")
                                .font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
                            Text("水平精度 ±\(fix.horizontalAccuracy.formatted(.number.precision(.fractionLength(1)))) m · \(fix.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption).foregroundStyle(fix.horizontalAccuracy > NavigationThresholds.weakAccuracy ? .orange : .secondary)
                        } else {
                            Text("等待有效的当前 GPS 定位…").foregroundStyle(.secondary)
                        }
                        Text(gps.lastSamplingMessage ?? gps.message)
                            .font(.caption).foregroundStyle(.secondary)
                        if let geometry {
                            Picker("此点标记为", selection: $captureNodeID) {
                                Text("普通采点").tag("")
                                ForEach(geometry.nodes) { node in
                                    Text(fieldNodeName(node.id)).tag(node.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(gps.sampling)
                            if !canCaptureNode {
                                Text("这个场地位置已记录，请选择另一个位置或调整旧点标记。")
                                    .font(.footnote).foregroundStyle(.orange)
                            }
                        }
                        if gps.sampling {
                            HStack {
                                Text("\(gps.samplingSecondsRemaining)").font(.largeTitle.bold().monospacedDigit())
                                Text("秒 · 请站稳，保持手机位置不变")
                                Spacer()
                            }
                            ProgressView(value: Double(Int(NavigationThresholds.sampleWindow) - gps.samplingSecondsRemaining),
                                         total: NavigationThresholds.sampleWindow)
                            Text("已收到 \(gps.samplingFixCount) 个定位更新")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button(gps.sampling ? "正在采样…" : "站稳后点按 · 采样 3 秒", systemImage: "mappin.and.ellipse") { capture() }
                            .buttonStyle(.borderedProminent)
                            .disabled(usableFix == nil || !canCaptureNode || gps.sampling)
                            .frame(maxWidth: .infinity)
                        Text("点按一次后倒计时 3、2、1。多次定位会过滤跳动后平均；若只有一个有效定位仍会保存，但明确提示未平均、建议重测。全部原始定位明细保留。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if survey.points.count >= 2 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("任意两点测距 / 补画线").font(.headline)
                            HStack {
                                Picker("起点", selection: $startPointID) {
                                    Text("选择起点").tag(nil as UUID?)
                                    ForEach(Array(survey.points.enumerated()), id: \.element.id) { index, point in
                                        Text("点 \(index + 1)").tag(point.id as UUID?)
                                    }
                                }
                                Picker("终点", selection: $endPointID) {
                                    Text("选择终点").tag(nil as UUID?)
                                    ForEach(Array(survey.points.enumerated()), id: \.element.id) { index, point in
                                        Text("点 \(index + 1)").tag(point.id as UUID?)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            if let startPointID, let endPointID, startPointID != endPointID,
                               let distance = survey.distanceMeters(from: startPointID, to: endPointID) {
                                Text("两点直线距离 \(distance.formatted(.number.precision(.fractionLength(2)))) m")
                                    .font(.subheadline.monospacedDigit())
                            }
                            Button("将这两点连成线", systemImage: "line.diagonal") {
                                guard let startPointID, let endPointID else { return }
                                store.addGPSSegment(to: surveyID, from: startPointID, to: endPointID)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canAddSegment)
                            Text("已标注的场地线自动连接；这里可测任意两点，或补画非模板线。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if !lines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(reconstruction == nil ? "已画线段 · 合计 \(survey.totalLineDistanceMeters(using: geometry).formatted(.number.precision(.fractionLength(2)))) m" : "手动与模板连接")
                                .font(.headline)
                            ForEach(lines) { line in
                                if let from = survey.pointNumber(for: line.fromPointID),
                                   let to = survey.pointNumber(for: line.toPointID),
                                   let distance = survey.distanceMeters(from: line.fromPointID, to: line.toPointID) {
                                    HStack {
                                        Text("点 \(from) — 点 \(to)\(line.isAutomatic ? " · 自动" : "")")
                                        Spacer()
                                        Text("\(distance.formatted(.number.precision(.fractionLength(2)))) m")
                                            .monospacedDigit()
                                        if let segmentID = line.manualSegmentID {
                                            Button(role: .destructive) {
                                                store.deleteGPSSegment(segmentID, from: surveyID)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .accessibilityLabel("删除点 \(from) 到点 \(to) 的线段")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !survey.points.isEmpty {
                        Button("导出采点 CSV", systemImage: "square.and.arrow.up") {
                            exportURL = store.csvExportURL(for: surveyID)
                            showShare = exportURL != nil
                        }.buttonStyle(.bordered)
                        if survey.points.contains(where: { $0.rawFixes != nil }) {
                            Button("导出 3 秒采样明细 CSV", systemImage: "square.and.arrow.up") {
                                exportURL = store.rawFixesCSVExportURL(for: surveyID)
                                showShare = exportURL != nil
                            }.buttonStyle(.bordered)
                        }
                        if !lines.isEmpty {
                            Button("导出线段 CSV", systemImage: "square.and.arrow.up") {
                                exportURL = store.segmentsCSVExportURL(for: surveyID)
                                showShare = exportURL != nil
                            }.buttonStyle(.bordered)
                        }
                        if reconstruction != nil {
                            Button("导出复原标线 CSV", systemImage: "square.and.arrow.up") {
                                exportURL = store.reconstructionCSVExportURL(for: surveyID)
                                showShare = exportURL != nil
                            }.buttonStyle(.bordered)
                        }
                        Text("测距使用 WGS84 地表直线距离；点位可以按任何顺序记录。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("全部采样点").font(.headline)
                        ForEach(Array(survey.points.enumerated()), id: \.element.id) { index, point in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("点 \(index + 1)").font(.headline)
                                    Spacer()
                                    Text(point.recordedAt.formatted(date: .abbreviated, time: .standard))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text("\(point.coordinate.latitude.formatted(.number.precision(.fractionLength(7))))°, \(point.coordinate.longitude.formatted(.number.precision(.fractionLength(7))))°")
                                    .font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
                                Text("GPS 水平精度 \(point.horizontalAccuracyMeters.formatted(.number.precision(.fractionLength(1)))) m")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let fixes = point.rawFixes, let spread = point.samplingSpreadMeters {
                                    Text(fixes.filter(\.usedInAverage).count >= 2
                                         ? "3 秒采样 · \(fixes.filter(\.usedInAverage).count)/\(fixes.count) 个定位用于平均 · 散布 \(spread.formatted(.number.precision(.fractionLength(1)))) m"
                                         : "3 秒采样 · 仅一个有效定位，未平均，建议重测")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if let geometry {
                                    Menu {
                                        Button("普通采点") { store.assignGPSPoint(point.id, in: surveyID, to: nil) }
                                        ForEach(geometry.nodes) { node in
                                            Button(fieldNodeName(node.id)) {
                                                store.assignGPSPoint(point.id, in: surveyID, to: node.id)
                                            }
                                        }
                                    } label: {
                                        Label(point.fieldNodeID.map(fieldNodeName) ?? "指定场地位置", systemImage: "sportscourt")
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    ContentUnavailableView("记录不存在", systemImage: "mappin.slash")
                }
            }.padding()
        }
        .navigationTitle("采点画布")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { gps.start() }
        .onDisappear { gps.stop() }
        .sheet(isPresented: $showShare) {
            if let exportURL { CSVShareSheet(url: exportURL) }
        }
        .sheet(isPresented: $showSaveField) {
            NavigationStack {
                Form {
                    TextField("球场名称",text: $fieldName)
                    if let survey,
                       let inference = SurveyInference.suggest(for: survey.points) {
                        let classification = SurveyFieldClassifier.classify(inference)
                        LabeledContent("识别类型",value: classification.title)
                        LabeledContent("实测尺寸",value: "\(inference.lengthMeters.formatted(.number.precision(.fractionLength(1)))) × \(inference.widthMeters.formatted(.number.precision(.fractionLength(1)))) m")
                    }
                    Text("保存后保留四个实测角点，并按识别出的 7v7 回撤线或标准场地结构生成可导航标线。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .navigationTitle("另存为球场")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showSaveField = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            guard let survey,
                                  let inference = SurveyInference.suggest(for: survey.points) else { return }
                            let templateID = survey.templateID ?? SurveyFieldClassifier.classify(inference).templateID
                            if store.saveGPSSurveyAsField(surveyID,name: fieldName,templateID: templateID) != nil {
                                savedFieldMessage = "“\(fieldName.trimmingCharacters(in: .whitespacesAndNewlines))”已保存，可从首页或新建场地使用。"
                                showSaveField = false
                            }
                        }.disabled(fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.presentationDetents([.medium])
        }
        .alert("球场已保存",isPresented: Binding(get: { savedFieldMessage != nil },set: { if !$0 { savedFieldMessage=nil } })) {
            Button("好") { savedFieldMessage=nil }
        } message: { Text(savedFieldMessage ?? "") }
    }
    private func capture() {
        guard usableFix != nil else { return }
        let selectedNodeID = captureNodeID
        gps.sampleDetailed(maximumAccuracy: NavigationThresholds.surveySampleMaximumAccuracy) { result in
            guard let result else { return }
            let acceptedTimestamps = Set(result.acceptedFixes.map(\.timestamp))
            var point = GPSPointRecord(
                coordinate: result.location.coordinate,
                recordedAt: result.location.timestamp,
                horizontalAccuracyMeters: result.location.accuracy,
                fieldNodeID: selectedNodeID.isEmpty ? nil : selectedNodeID
            )
            point.samplingDurationSeconds = NavigationThresholds.sampleWindow
            point.samplingSpreadMeters = result.spreadMeters
            point.rawFixes = result.receivedFixes.map { fix in
                GPSFixRecord(coordinate: fix.coordinate, recordedAt: fix.timestamp,
                             horizontalAccuracyMeters: fix.accuracy,
                             usedInAverage: acceptedTimestamps.contains(fix.timestamp))
            }
            if store.appendGPSPoint(point, to: surveyID) { captureNodeID = "" }
        }
    }
}

private struct CSVShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private func fieldNodeName(_ id: String) -> String {
    switch id {
    case "A": return "A · 上端左角"
    case "B": return "B · 上端右角"
    case "C": return "C · 下端右角"
    case "D": return "D · 下端左角"
    case "HL1": return "中线左端"
    case "HL2": return "中线右端"
    case "CENTER": return "中心点"
    case "SPOT-TOP": return "上端罚球点"
    case "SPOT-BOTTOM": return "下端罚球点"
    case "BOL-TOP-L": return "上方回撤线左端"
    case "BOL-TOP-R": return "上方回撤线右端"
    case "BOL-BOTTOM-L": return "下方回撤线左端"
    case "BOL-BOTTOM-R": return "下方回撤线右端"
    default:
        let parts = id.split(separator: "-")
        if parts.count == 3, let number = Int(parts[2]), (1...4).contains(number) {
            let area = parts[0] == "PA" ? "禁区" : "小禁区"
            let side = parts[1] == "TOP" ? "上端" : "下端"
            let corner = ["底线左端", "前沿左角", "前沿右角", "底线右端"][number - 1]
            return "\(side)\(area)\(corner)"
        }
        return id
    }
}

struct GPSPointsCanvas: View {
    let points: [GPSPointRecord]
    let lines: [GPSSurveyLine]
    let reconstruction: SurveyReconstruction?
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: bounds, cornerRadius: 18), with: .color(Color(red: 0.07, green: 0.18, blue: 0.22)))
            guard let first = points.first else {
                context.draw(Text("点击“记录当前位置”添加第一个点")
                    .font(.subheadline).foregroundColor(.white.opacity(0.75)),
                    at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            let rawLocal = points.map { Geo.local($0.coordinate, origin: first.coordinate) }
            let coordinateByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.coordinate) })
            let orientation: (Point, Point, Point)? = {
                guard let ids = reconstruction?.inference.cornerPointIDs, ids.count == 4,
                      let aCoord = coordinateByID[ids[0]],
                      let bCoord = coordinateByID[ids[1]],
                      let dCoord = coordinateByID[ids[3]] else { return nil }
                let a = Geo.local(aCoord, origin: first.coordinate)
                let width = Geo.local(bCoord, origin: first.coordinate) - a
                let length = Geo.local(dCoord, origin: first.coordinate) - a
                guard length.magnitude > 1 else { return nil }
                let forward = Point(x: length.x / length.magnitude, y: length.y / length.magnitude)
                var right = Point(x: forward.y, y: -forward.x)
                if width.x * right.x + width.y * right.y < 0 {
                    right = Point(x: -right.x, y: -right.y)
                }
                return (a, right, forward)
            }()
            func display(_ point: Point) -> Point {
                guard let orientation else { return point }
                let offset = point - orientation.0
                return Point(x: offset.x * orientation.1.x + offset.y * orientation.1.y,
                             y: -(offset.x * orientation.2.x + offset.y * orientation.2.y))
            }
            let local = rawLocal.map(display)
            let reconstructedCoordinates = (reconstruction?.lines.flatMap { [$0.from, $0.to] } ?? []) +
                (reconstruction?.marks.map(\.coordinate) ?? [])
            let boundsPoints = local + reconstructedCoordinates.map { display(Geo.local($0, origin: first.coordinate)) }
            let minX = min(boundsPoints.map(\.x).min() ?? 0, 0), maxX = max(boundsPoints.map(\.x).max() ?? 0, 0)
            let minY = min(boundsPoints.map(\.y).min() ?? 0, 0), maxY = max(boundsPoints.map(\.y).max() ?? 0, 0)
            let rangeX = max(10, maxX - minX), rangeY = max(10, maxY - minY)
            let scale = min((size.width - 76) / rangeX, (size.height - 76) / rangeY)
            let centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2
            func screen(_ point: Point) -> CGPoint {
                CGPoint(x: size.width/2 + (point.x - centerX)*scale,
                        y: size.height/2 - (point.y - centerY)*scale)
            }
            context.draw(Text(orientation == nil ? "N ↑" : "场地对正")
                .font(.caption.bold()).foregroundColor(.white.opacity(0.75)),
                at: CGPoint(x: size.width - (orientation == nil ? 30 : 46), y: 24))
            let positions = Dictionary(uniqueKeysWithValues: zip(points.map(\.id), local))
            let coordinates = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.coordinate) })
            var labels: [(text: String, point: CGPoint, color: Color)] = []
            var occupied = local.map { point in
                let center = screen(point)
                return CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)
            }
            func label(_ meters: Double, from start: CGPoint, to end: CGPoint, color: Color) {
                let title = "\(meters.formatted(.number.precision(.fractionLength(1)))) m"
                let width = max(52, CGFloat(title.count) * 6 + 12)
                let dx = end.x - start.x, dy = end.y - start.y
                let length = max(1, hypot(dx, dy))
                for offset in [CGFloat(0), 12, -12, 24, -24, 36, -36] {
                    for fraction in [CGFloat(0.5), 0.35, 0.65, 0.2, 0.8] {
                        let center = CGPoint(x: start.x + dx * fraction - dy / length * offset,
                                             y: start.y + dy * fraction + dx / length * offset)
                        let rect = CGRect(x: center.x - width / 2, y: center.y - 11, width: width, height: 22)
                        guard bounds.insetBy(dx: 3, dy: 3).contains(rect),
                              !occupied.contains(where: { $0.insetBy(dx: -3, dy: -3).intersects(rect) }) else { continue }
                        occupied.append(rect)
                        labels.append((title, center, color))
                        return
                    }
                }
                // Keep a distance visible even on a crowded drawing.
                let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                labels.append((title, center, color))
            }
            if let reconstruction {
                for segment in reconstruction.lines {
                    let from = screen(display(Geo.local(segment.from, origin: first.coordinate)))
                    let to = screen(display(Geo.local(segment.to, origin: first.coordinate)))
                    let color: Color = switch segment.feature {
                    case .boundary: .white
                    case .halfway: .white.opacity(0.7)
                    case .penaltyArea: segment.source == .mirrored ? .cyan : .mint
                    case .goalArea: segment.source == .mirrored ? .purple : .yellow
                    case .buildOut: .blue
                    case .penaltySpot: .pink
                    }
                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    let dashed = segment.source == .mirrored || segment.feature == .halfway
                    context.stroke(path, with: .color(color), style: StrokeStyle(
                        lineWidth: segment.feature == .boundary ? 2.5 : 2,
                        lineCap: .round, dash: dashed ? [6, 4] : []))
                    label(segment.meters, from: from, to: to, color: color)
                }
                for mark in reconstruction.marks {
                    let point = screen(display(Geo.local(mark.coordinate, origin: first.coordinate)))
                    let color: Color = mark.source == .mirrored ? .cyan : .pink
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(color))
                }
            }
            for lineSegment in lines {
                guard let start = positions[lineSegment.fromPointID], let end = positions[lineSegment.toPointID] else { continue }
                let startScreen = screen(start), endScreen = screen(end)
                var line = Path()
                line.move(to: startScreen)
                line.addLine(to: endScreen)
                context.stroke(line, with: .color(.mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                if let from = coordinates[lineSegment.fromPointID], let to = coordinates[lineSegment.toPointID] {
                    label(Geo.distanceMeters(from, to), from: startScreen, to: endScreen, color: .mint)
                }
            }
            for point in local {
                let p = screen(point)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.orange))
            }
            for label in labels {
                let width = max(52, CGFloat(label.text.count) * 6 + 12)
                let labelBounds = CGRect(x: label.point.x - width / 2, y: label.point.y - 11, width: width, height: 22)
                context.fill(Path(roundedRect: labelBounds, cornerRadius: 6),
                             with: .color(Color(red: 0.07, green: 0.18, blue: 0.22)))
                context.draw(Text(label.text).font(.system(size: 11, weight: .bold)).foregroundColor(label.color),
                             at: label.point)
            }
            let keyIDs: Set<UUID>? = reconstruction.map { model in
                Set(model.inference.cornerPointIDs + model.inference.penaltyFrontPointIDs +
                    model.inference.goalFrontPointIDs + [model.inference.penaltySpotPointID].compactMap { $0 })
            }
            for (index, point) in local.enumerated() {
                if let keyIDs, !keyIDs.contains(points[index].id) { continue }
                let p = screen(point)
                let title = "\(index + 1)"
                let width = CGFloat(title.count) * 8 + 8
                let candidates = [CGPoint(x: p.x + 12, y: p.y - 15), CGPoint(x: p.x - 12, y: p.y - 15),
                                  CGPoint(x: p.x + 12, y: p.y + 15), CGPoint(x: p.x - 12, y: p.y + 15),
                                  CGPoint(x: p.x, y: p.y - 22), CGPoint(x: p.x, y: p.y + 22)]
                if let chosen = candidates.first(where: { center in
                    let rect = CGRect(x: center.x - width / 2, y: center.y - 10, width: width, height: 20)
                    return bounds.insetBy(dx: 3, dy: 3).contains(rect) &&
                        !occupied.contains { $0.insetBy(dx: -2, dy: -2).intersects(rect) }
                }) {
                    occupied.append(CGRect(x: chosen.x - width / 2, y: chosen.y - 10, width: width, height: 20))
                    context.draw(Text(title).font(.caption.bold()).foregroundColor(.white), at: chosen)
                }
            }
        }
        .accessibilityLabel("GPS 采点画布，\(points.count) 个原始点，\(reconstruction?.lines.count ?? lines.count) 条场地线；\(reconstruction == nil ? "北在上" : "按场地长边对正")")
    }
}
