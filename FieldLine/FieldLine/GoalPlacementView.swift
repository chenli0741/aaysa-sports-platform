import SwiftUI

struct GoalPlacementView: View {
    private enum CaptureRole: CaseIterable, Hashable {
        case reference1
        case reference2
        case goalEnd1
        case goalEnd2
    }
    @StateObject private var gps = LocationService()
    @State private var samples: [CaptureRole: LocationSample] = [:]
    @State private var goalWidthText = "5"
    @State private var activeRole: CaptureRole?
    @State private var validationSample: LocationSample?
    @State private var validationMessage: String?

    private var setup: GoalPlacementSetup? {
        guard let reference1 = samples[.reference1]?.coordinate,
              let reference2 = samples[.reference2]?.coordinate,
              let width = Double(goalWidthText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")),
              width.isFinite, width >= 1 else { return nil }
        return .init(reference1: reference1, reference2: reference2, goalWidth: width)
    }
    private var measuredGoalWidth: Double? {
        guard let first = samples[.goalEnd1]?.coordinate,
              let second = samples[.goalEnd2]?.coordinate else { return nil }
        return Geo.distanceMeters(first, second)
    }
    private var validation: GoalPostValidation? {
        guard let setup, let validationSample else { return nil }
        return setup.validate(post: validationSample.coordinate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("确定球门位置").font(.title2.bold())
                    Text("底线上的两个同类、左右对称的点确定中心；球门宽度默认 5 m，可直接修改，也可采集两个球门端点自动填入。采集时，球门现在放在哪里、朝哪个方向都不影响计算。")
                        .foregroundStyle(.secondary)
                }

                captureSection(title: "1. 采集两个底线基准点",
                               detail: "两点必须在同一条底线上、属于同一类标记，并位于球门左右对称的位置。例如两个外角，或禁区两侧与底线的交点。",
                               roles: [.reference1, .reference2])

                VStack(alignment: .leading, spacing: 12) {
                    Text("2. 设置球门宽度").font(.headline)
                    HStack {
                        TextField("球门宽度", text: $goalWidthText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("球门宽度，米")
                            .onChange(of: goalWidthText) { _, _ in validationSample = nil }
                        Text("m").foregroundStyle(.secondary)
                    }
                    Text("请输入两个门柱内侧之间的距离；也可以在下方采集端点。")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("采集球门端点（可选）").font(.subheadline.bold())
                    Text("分别在两个端点采样。两个点采完后，实测距离会自动填入上方输入框，仍可手动修改。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    captureRows([.goalEnd1, .goalEnd2])
                    if let measuredGoalWidth {
                        Text("两端点 GPS 测得 \(measuredGoalWidth.formatted(.number.precision(.fractionLength(2)))) m")
                            .font(.subheadline).foregroundStyle(.teal)
                        Text("球门宽度较短，手机 GPS 误差可能超过实测宽度；放置门柱前请用卷尺复核。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if setup == nil, samples[.reference1] != nil, samples[.reference2] != nil {
                        Text("请输入至少 1 m 的有效球门宽度。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                if let setup {
                    setupSummary(setup)
                    validationSection(setup)
                }

                Button("全部重新设置", role: .destructive) {
                    samples = [:]
                    goalWidthText = "5"
                    validationSample = nil
                    validationMessage = nil
                }
                .disabled(samples.isEmpty && goalWidthText == "5" && validationSample == nil)
            }
            .padding()
        }
        .navigationTitle("球门放置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { gps.start() }
        .onDisappear { gps.stop() }
    }

    private func captureSection(title: String, detail: String, roles: [CaptureRole]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            captureRows(roles)
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private func captureRows(_ roles: [CaptureRole]) -> some View {
        ForEach(roles, id: \.self) { role in
            HStack(spacing: 12) {
                Image(systemName: samples[role] == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(samples[role] == nil ? Color.secondary : Color.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label(for: role)).fontWeight(.semibold)
                    if let sample = samples[role] {
                        Text("已采集 · GPS ±\(sample.accuracy.formatted(.number.precision(.fractionLength(1)))) m")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(samples[role] == nil ? "采集" : "重采") { capture(role) }
                    .buttonStyle(.bordered)
                    .disabled(gps.sampling)
            }
        }
        if gps.sampling, let activeRole, roles.contains(activeRole) {
            ProgressView("正在采样… \(gps.samplingSecondsRemaining) 秒")
        }
    }

    private func setupSummary(_ setup: GoalPlacementSetup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(setup.isUsable ? "设置完成" : "这组点无法使用",
                  systemImage: setup.isUsable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(setup.isUsable ? .teal : .orange)
            Text("两个对称基准点相距 \(setup.referenceDistance.formatted(.number.precision(.fractionLength(2)))) m")
            Text("球门宽度 \(setup.goalWidth.formatted(.number.precision(.fractionLength(2)))) m")
            if setup.isUsable {
                Text("目标门柱位置：从第一个基准点沿底线分别量 \(((setup.referenceDistance - setup.goalWidth) / 2).formatted(.number.precision(.fractionLength(2)))) m 和 \(((setup.referenceDistance + setup.goalWidth) / 2).formatted(.number.precision(.fractionLength(2)))) m。")
                    .font(.subheadline)
            } else {
                Text("两个基准点必须在同一底线上并左右对称，而且它们的间距必须大于球门宽度。")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background((setup.isUsable ? Color.teal : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func validationSection(_ setup: GoalPlacementSetup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3. 校验任意一个门柱端点").font(.headline)
            Text("把手机放到任意一个门柱端点并采样。系统会自动匹配距离最近的目标端点。")
                .font(.subheadline).foregroundStyle(.secondary)
            Button(validationSample == nil ? "校验当前门柱点" : "重新校验当前门柱点",
                   systemImage: "scope") { captureValidation() }
                .buttonStyle(.borderedProminent)
                .disabled(!setup.isUsable || gps.sampling)
            if gps.sampling, activeRole == nil {
                ProgressView("正在校验… \(gps.samplingSecondsRemaining) 秒")
            }
            if let validation, let sample = validationSample {
                Divider()
                Text("自动匹配：目标门柱 \(validation.targetIndex)").font(.headline)
                if validation.distanceToTarget <= max(0.5, sample.accuracy) {
                    Text("这个端点已在 GPS 误差范围内").font(.title3.bold()).foregroundStyle(.teal)
                } else {
                    Text("离正确端点约 \(validation.distanceToTarget.formatted(.number.precision(.fractionLength(2)))) m")
                        .font(.title3.bold()).foregroundStyle(.orange)
                    if abs(validation.alongOffset) > 0.2 {
                        Text(validation.alongOffset > 0
                             ? "沿底线向第一个基准点方向移动 \(abs(validation.alongOffset).formatted(.number.precision(.fractionLength(2)))) m"
                             : "沿底线向第二个基准点方向移动 \(abs(validation.alongOffset).formatted(.number.precision(.fractionLength(2)))) m")
                    }
                    if abs(validation.crossTrack) > 0.2 {
                        Text("同时回到底线约 \(abs(validation.crossTrack).formatted(.number.precision(.fractionLength(2)))) m")
                    }
                }
                Text("本次 GPS ±\(sample.accuracy.formatted(.number.precision(.fractionLength(1)))) m。最后请用卷尺复核。")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let validationMessage {
                Text(validationMessage).font(.caption).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func label(for role: CaptureRole) -> String {
        switch role {
        case .reference1: "基准点 1"
        case .reference2: "基准点 2"
        case .goalEnd1: "球门端点 1"
        case .goalEnd2: "球门端点 2"
        }
    }

    private func capture(_ role: CaptureRole) {
        activeRole = role
        validationMessage = nil
        gps.sampleDetailed(maximumAccuracy: NavigationThresholds.clubAnchorMaximumAccuracy,
                           minimumFixes: 1,
                           preferredAccuracy: NavigationThresholds.weakAccuracy,
                           maximumDuration: Int(NavigationThresholds.sampleWindow)) { result in
            if let result {
                samples[role] = result.location
                if role == .goalEnd1 || role == .goalEnd2, let measuredGoalWidth {
                    goalWidthText = measuredGoalWidth.formatted(.number.precision(.fractionLength(2)))
                }
                validationSample = nil
            } else {
                validationMessage = gps.lastSamplingMessage
            }
            activeRole = nil
        }
    }

    private func captureValidation() {
        activeRole = nil
        validationMessage = nil
        gps.sampleDetailed(maximumAccuracy: NavigationThresholds.clubAnchorMaximumAccuracy,
                           minimumFixes: 1,
                           preferredAccuracy: NavigationThresholds.weakAccuracy,
                           maximumDuration: Int(NavigationThresholds.sampleWindow)) { result in
            validationSample = result?.location
            validationMessage = result == nil ? gps.lastSamplingMessage : nil
        }
    }
}
