import AppKit
import Combine
import ServiceManagement
import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case display
    case sound
    case integration
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用"
        case .display: return "显示"
        case .sound: return "声音"
        case .integration: return "集成"
        case .about: return "关于"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "系统与基础行为"
        case .display: return "显示器与位置"
        case .sound: return "通知与提示音"
        case .integration: return "Claude Code 集成"
        case .about: return "版本与更新"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .display: return "rectangle.on.rectangle"
        case .sound: return "speaker.wave.2.fill"
        case .integration: return "link.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return Color(red: 0.12, green: 0.42, blue: 0.95)
        case .display: return Color(red: 0.46, green: 0.40, blue: 0.96)
        case .sound: return Color(red: 0.22, green: 0.83, blue: 0.42)
        case .integration: return Color(red: 0.16, green: 0.76, blue: 0.72)
        case .about: return Color(red: 0.17, green: 0.60, blue: 0.96)
        }
    }
}

@MainActor
final class SettingsPanelViewModel: ObservableObject {
    @Published var launchAtLogin = false
    @Published var hooksInstalled = false
    @Published var accessibilityEnabled = false

    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        hooksInstalled = HookInstaller.isInstalled()
        accessibilityEnabled = AXIsProcessTrusted()
        ScreenSelector.shared.refreshScreens()
        SoundPackCatalog.shared.refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func setHooksInstalled(_ enabled: Bool) {
        if enabled {
            HookInstaller.installIfNeeded()
        } else {
            HookInstaller.uninstall()
        }
        hooksInstalled = HookInstaller.isInstalled()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private enum SettingsPanelPresentation {
    case window
    case popover
}

private struct SettingsSidebarSection: Identifiable {
    let title: String?
    let categories: [SettingsCategory]

    var id: String { title ?? categories.map(\.rawValue).joined(separator: "-") }
}

private struct SettingsGlassSurface: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

private enum SettingsPanelMetrics {
    static let windowSize = CGSize(width: 648, height: 522)
    static let popoverSize = CGSize(width: 760, height: 620)
    static let windowSidebarWidth: CGFloat = 236
    static let popoverSidebarWidth: CGFloat = 212
    static let windowTitlebarHeight: CGFloat = 34
    static let windowContentTopInset: CGFloat = 46
    static let popoverTitlebarHeight: CGFloat = 0
    static let popoverContentTopInset: CGFloat = 0
    static let outerPadding: CGFloat = 10
}

private struct SettingsPanelContentView: View {
    let presentation: SettingsPanelPresentation

    @StateObject private var viewModel = SettingsPanelViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var screenSelector = ScreenSelector.shared
    @ObservedObject private var soundPacks = SoundPackCatalog.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var selectedCategory: SettingsCategory? = .general

    var body: some View {
        ZStack {
            SettingsGlassSurface(material: .hudWindow, blendingMode: .behindWindow)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.28, blue: 0.32).opacity(0.62),
                            Color(red: 0.15, green: 0.16, blue: 0.19).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()

            if presentation == .window {
                titlebarBackground
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.top, contentTopInset)
            .padding(.horizontal, SettingsPanelMetrics.outerPadding)
            .padding(.bottom, SettingsPanelMetrics.outerPadding)
            .frame(
                minWidth: minimumWidth,
                idealWidth: idealWidth,
                minHeight: minimumHeight,
                idealHeight: idealHeight,
                alignment: .topLeading
            )
        }
        .background(panelBackgroundColor)
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 30, y: 18)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.refresh()
            ensureValidSelectedSoundPack()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
            ensureValidSelectedSoundPack()
        }
        .onChange(of: soundPacks.availablePacks) { _, _ in
            ensureValidSelectedSoundPack()
        }
    }

    private var minimumWidth: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowSize.width
        case .popover:
            return SettingsPanelMetrics.popoverSize.width
        }
    }

    private var idealWidth: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowSize.width
        case .popover:
            return SettingsPanelMetrics.popoverSize.width
        }
    }

    private var minimumHeight: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowSize.height
        case .popover:
            return SettingsPanelMetrics.popoverSize.height
        }
    }

    private var idealHeight: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowSize.height
        case .popover:
            return SettingsPanelMetrics.popoverSize.height
        }
    }

    private var sidebarWidth: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowSidebarWidth
        case .popover:
            return SettingsPanelMetrics.popoverSidebarWidth
        }
    }

    private var panelBackgroundColor: Color {
        .clear
    }

    private var titlebarHeight: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowTitlebarHeight
        case .popover:
            return SettingsPanelMetrics.popoverTitlebarHeight
        }
    }

    private var contentTopInset: CGFloat {
        switch presentation {
        case .window:
            return SettingsPanelMetrics.windowContentTopInset
        case .popover:
            return SettingsPanelMetrics.popoverContentTopInset
        }
    }

    private var titlebarBackground: some View {
        ZStack {
            SettingsGlassSurface(material: .headerView, blendingMode: .withinWindow)

            Rectangle()
                .fill(Color(red: 0.19, green: 0.24, blue: 0.31).opacity(0.68))

            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.38, blue: 0.49).opacity(0.34),
                    Color(red: 0.12, green: 0.15, blue: 0.20).opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.24))
                .frame(height: 1)
        }
        .frame(height: titlebarHeight)
    }

    private var sidebarSections: [SettingsSidebarSection] {
        [
            SettingsSidebarSection(
                title: nil,
                categories: [.general, .display, .sound, .integration, .about]
            )
        ]
    }

    private var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sidebarSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = section.title {
                            Text(title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.32))
                                .padding(.horizontal, 12)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(section.categories) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    SidebarItemView(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    SettingsGlassSurface(material: .sidebar, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .opacity(0.82)
                }
        )
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                switch selectedCategory ?? .general {
                case .general:
                    generalContent
                case .display:
                    displayContent
                case .sound:
                    soundContent
                case .integration:
                    integrationContent
                case .about:
                    aboutContent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.025),
                    Color.white.opacity(0.008),
                    Color.black.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((selectedCategory ?? .general).title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)

            Text((selectedCategory ?? .general).subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionCard(title: "系统") {
                SettingsToggleLine(
                    title: "登录时打开",
                    subtitle: "启动 macOS 后自动显示 Island",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.setLaunchAtLogin($0) }
                    )
                )
                SettingsLineDivider()

                SettingsInfoLine(title: "显示器", subtitle: "选择 Island 所在显示器") {
                    screenPicker
                }
            }

            SettingsSectionCard(title: "行为") {
                SettingsToggleLine(
                    title: "全屏时隐藏",
                    subtitle: "当前台应用进入全屏时，暂停 Island 的展开与悬停交互",
                    isOn: $settings.hideInFullscreen
                )
                SettingsLineDivider()

                SettingsToggleLine(
                    title: "智能抑制",
                    subtitle: "当前正在看终端时，不自动弹出通知面板",
                    isOn: $settings.smartSuppression
                )
                SettingsLineDivider()

                SettingsToggleLine(
                    title: "鼠标离开时自动收起",
                    subtitle: "hover 展开的预览面板会在鼠标离开后自动关闭",
                    isOn: $settings.autoCollapseOnLeave
                )
            }

            SettingsSectionCard(title: "应用") {
                SettingsActionLine(
                    title: "退出应用",
                    subtitle: "立即关闭 Island"
                ) {
                    NSApplication.shared.terminate(nil)
                } accessory: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
        }
    }

    private var displayContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionCard(title: "显示器") {
                SettingsInfoLine(
                    title: "当前显示器",
                    subtitle: "切换后会重新挂载 Island 窗口位置"
                ) {
                    screenPicker
                }
                SettingsLineDivider()

                if let selectedScreen = screenSelector.selectedScreen {
                    SettingsValueLine(
                        title: "当前输出",
                        value: selectedScreen.localizedName
                    )
                    SettingsLineDivider()
                }

                SettingsValueLine(
                    title: "选择策略",
                    value: screenSelector.selectionMode == .automatic ? "自动" : "手动指定"
                )
            }

            SettingsSectionCard(title: "面板") {
                SettingsToggleLine(
                    title: "显示代理活动详情",
                    subtitle: "在会话列表和 hover 预览里展示工具调用、思考与更细的状态描述",
                    isOn: $settings.showAgentDetail
                )
                SettingsLineDivider()

                SettingsSliderLine(
                    title: "内容字号",
                    subtitle: "调整会话列表、hover 预览和结果视图的文字大小",
                    value: $settings.contentFontSize,
                    range: 11...17,
                    step: 1,
                    format: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )
                SettingsLineDivider()

                SettingsSliderLine(
                    title: "最大面板高度",
                    subtitle: "控制聊天面板和 hover 预览的最大展开高度",
                    value: $settings.maxPanelHeight,
                    range: 480...700,
                    step: 10,
                    format: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )
            }

            SettingsSectionCard(title: "宠物") {
                SettingsInfoLine(
                    title: "刘海宠物",
                    subtitle: settings.notchPetStyle.subtitle
                ) {
                    notchPetPicker
                }

                SettingsValueLine(
                    title: "当前角色",
                    value: settings.notchPetStyle.title
                )
            }
        }
    }

    private var soundContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionCard(title: "通知") {
                SettingsToggleLine(
                    title: "启用提示音",
                    subtitle: "Claude 开始处理、需要你介入、完成时可分别播放不同音效。",
                    isOn: $settings.soundEnabled
                )
                SettingsLineDivider()

                SettingsInfoLine(
                    title: "声音模式",
                    subtitle: "系统音适合快速配置；主题包兼容 OpenPeon / CESP 格式。"
                ) {
                    soundThemeModePicker
                }
                SettingsLineDivider()

                SettingsSliderLine(
                    title: "音量",
                    subtitle: "控制 Island 播放提示音时的音量大小",
                    value: $settings.soundVolume,
                    range: 0...1,
                    step: 0.05,
                    format: { "\(Int(($0 * 100).rounded()))%" }
                )
            }

            if settings.soundThemeMode == .builtIn {
                SettingsSectionCard(title: "阶段音效") {
                    ForEach(NotificationEvent.allCases) { event in
                        SoundEventSettingsLine(
                            event: event,
                            isEnabled: Binding(
                                get: { AppSettings.isSoundEnabled(for: event) },
                                set: { AppSettings.setSoundEnabled($0, for: event) }
                            ),
                            selectedSound: Binding(
                                get: { AppSettings.sound(for: event) },
                                set: { AppSettings.setSound($0, for: event) }
                            )
                        ) {
                            AppSettings.playSound(for: event)
                        }
                    }
                }
            } else {
                SettingsSectionCard(title: "主题音效包") {
                    SettingsInfoLine(
                        title: "当前主题包",
                        subtitle: "从 `~/.openpeon/packs`、项目 `.claude/hooks/peon-ping/packs`，或手动导入的目录中选择。"
                    ) {
                        soundPackPicker
                    }

                    SettingsActionLine(
                        title: "导入本地主题包",
                        subtitle: "选择一个包含 `openpeon.json` 的目录，将其加入可选列表。"
                    ) {
                        if soundPacks.importPack(), soundPacks.pack(for: settings.selectedSoundPackPath) == nil {
                            settings.selectedSoundPackPath = soundPacks.availablePacks.first?.rootURL.path ?? ""
                        }
                    } accessory: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                    }

                    if soundPacks.availablePacks.isEmpty {
                        SettingsValueLine(title: "可用主题包", value: "未发现")
                    } else {
                        SettingsValueLine(title: "可用主题包", value: "\(soundPacks.availablePacks.count)")
                    }
                }

                SettingsSectionCard(title: "阶段映射") {
                    ForEach(NotificationEvent.allCases) { event in
                        SoundPackEventLine(
                            event: event,
                            isEnabled: Binding(
                                get: { AppSettings.isSoundEnabled(for: event) },
                                set: { AppSettings.setSoundEnabled($0, for: event) }
                            )
                        ) {
                            AppSettings.playSound(for: event)
                        }
                    }
                }
            }
        }
    }

    private var integrationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionCard(title: "Claude Hooks") {
                SettingsToggleLine(
                    title: "启用 Hooks",
                    subtitle: "在 Claude Code 中安装 Island 所需的 hook 脚本"
                        ,
                    isOn: Binding(
                        get: { viewModel.hooksInstalled },
                        set: { viewModel.setHooksInstalled($0) }
                    )
                )
            }

            SettingsSectionCard(title: "系统权限") {
                SettingsStatusLine(
                    title: "辅助功能",
                    subtitle: viewModel.accessibilityEnabled ? "已授权，可进行窗口聚焦与前台检测" : "未授权，部分自动聚焦能力不可用",
                    status: viewModel.accessibilityEnabled ? "已开启" : "待开启",
                    statusColor: viewModel.accessibilityEnabled ? TerminalColors.green : TerminalColors.amber
                ) {
                    if !viewModel.accessibilityEnabled {
                        viewModel.openAccessibilitySettings()
                    }
                }
            }
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionCard(title: "应用信息") {
                SettingsValueLine(title: "版本", value: appVersion)
                SettingsLineDivider()
                SettingsValueLine(title: "构建", value: appBuild)
            }

            SettingsSectionCard(title: "更新") {
                SettingsActionLine(
                    title: updateTitle,
                    subtitle: updateSubtitle
                ) {
                    handleUpdateAction()
                } accessory: {
                    updateAccessory
                }
            }

            SettingsSectionCard(title: "链接") {
                SettingsActionLine(title: "GitHub", subtitle: "查看项目主页并反馈问题") {
                    if let url = URL(string: "https://github.com/wudanwu/Island") {
                        NSWorkspace.shared.open(url)
                    }
                } accessory: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var screenPicker: some View {
        Picker("显示器", selection: screenSelectionBinding) {
            Text("自动").tag("automatic")
            ForEach(screenSelector.availableScreens, id: \.self) { screen in
                Text(screen.localizedName).tag(screenToken(for: screen))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 180)
    }

    private var soundThemeModePicker: some View {
        Picker("声音模式", selection: $settings.soundThemeMode) {
            ForEach(SoundThemeMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 180)
    }

    private var soundPackPicker: some View {
        Picker("主题包", selection: $settings.selectedSoundPackPath) {
            if soundPacks.availablePacks.isEmpty {
                Text("未发现").tag("")
            } else {
                ForEach(soundPacks.availablePacks) { pack in
                    Text(pack.displayName).tag(pack.rootURL.path)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 220)
    }

    private var notchPetPicker: some View {
        Picker("刘海宠物", selection: $settings.notchPetStyle) {
            ForEach(NotchPetStyle.allCases) { pet in
                Text(pet.title).tag(pet)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 180)
    }

    private var screenSelectionBinding: Binding<String> {
        Binding(
            get: {
                if screenSelector.selectionMode == .automatic {
                    return "automatic"
                }
                if let selected = screenSelector.selectedScreen {
                    return screenToken(for: selected)
                }
                return "automatic"
            },
            set: { token in
                if token == "automatic" {
                    screenSelector.selectAutomatic()
                } else if let screen = screenSelector.availableScreens.first(where: { screenToken(for: $0) == token }) {
                    screenSelector.selectScreen(screen)
                }
                NotificationCenter.default.post(
                    name: NSApplication.didChangeScreenParametersNotification,
                    object: nil
                )
            }
        )
    }

    private func screenToken(for screen: NSScreen) -> String {
        let identifier = ScreenIdentifier(screen: screen)
        return "\(identifier.displayID ?? 0)-\(identifier.localizedName)"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var updateTitle: String {
        switch updateManager.state {
        case .idle, .upToDate:
            return "检查更新"
        case .checking:
            return "检查中..."
        case .found:
            return "下载更新"
        case .downloading:
            return "下载中..."
        case .extracting:
            return "解压中..."
        case .readyToInstall:
            return "安装并重启"
        case .installing:
            return "安装中..."
        case .error:
            return "重试更新"
        }
    }

    private var updateSubtitle: String {
        switch updateManager.state {
        case .idle:
            return "检查 Island 是否有新版本"
        case .upToDate:
            return "当前已经是最新版本"
        case .checking:
            return "正在连接更新源"
        case .found(let version, _):
            return "发现新版本 v\(version)"
        case .downloading(let progress):
            return "下载进度 \(Int(progress * 100))%"
        case .extracting(let progress):
            return "解压进度 \(Int(progress * 100))%"
        case .readyToInstall(let version):
            return "已准备安装 v\(version)"
        case .installing:
            return "正在替换应用并准备重启"
        case .error:
            return "更新失败，点击后重新尝试"
        }
    }

    @ViewBuilder
    private var updateAccessory: some View {
        switch updateManager.state {
        case .checking, .downloading, .extracting, .installing:
            ProgressView()
                .controlSize(.small)
        case .upToDate:
            Text("最新")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(TerminalColors.green)
        case .found(let version, _), .readyToInstall(let version):
            Text("v\(version)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(TerminalColors.green)
        case .idle, .error:
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private func handleUpdateAction() {
        switch updateManager.state {
        case .idle, .upToDate, .error:
            updateManager.checkForUpdates()
        case .found:
            updateManager.downloadAndInstall()
        case .readyToInstall:
            updateManager.installAndRelaunch()
        case .checking, .downloading, .extracting, .installing:
            break
        }
    }

    private func ensureValidSelectedSoundPack() {
        guard settings.soundThemeMode == .soundPack else { return }
        if soundPacks.availablePacks.isEmpty {
            settings.selectedSoundPackPath = ""
        } else if soundPacks.pack(for: settings.selectedSoundPackPath) == nil {
            settings.selectedSoundPackPath = soundPacks.availablePacks.first?.rootURL.path ?? ""
        }
    }
}

struct SettingsWindowView: View {
    var body: some View {
        SettingsPanelContentView(presentation: .window)
    }
}

struct NotchSettingsPopoverView: View {
    var body: some View {
        SettingsPanelContentView(presentation: .popover)
            .frame(width: SettingsPanelMetrics.popoverSize.width, height: SettingsPanelMetrics.popoverSize.height)
    }
}

private struct SidebarItemView: View {
    let category: SettingsCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(isSelected ? 0.95 : 1))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.22) : category.tint.opacity(0.86))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(category.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(isSelected ? 0.92 : 0.55))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(isSelected ? 0.08 : 0), lineWidth: 1)
        )
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        SettingsGlassSurface(material: .hudWindow, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .opacity(0.96)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.025),
                                        Color.black.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
        }
    }
}

private struct SettingsLineDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.10))
            .padding(.horizontal, 18)
    }
}

private struct SettingsToggleLine: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.clear)
    }
}

private struct SettingsInfoLine<Accessory: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            accessory
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct SettingsActionLine<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let action: () -> Void
    @ViewBuilder let accessory: Accessory

    var body: some View {
        Button(action: action) {
            SettingsInfoLine(title: title, subtitle: subtitle) {
                accessory
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct SettingsSliderLine: View {
    let title: String
    let subtitle: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                Text(format(value))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
            }

            Slider(value: $value, in: range, step: step)
                .tint(TerminalColors.blue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct SettingsStatusLine: View {
    let title: String
    let subtitle: String?
    let status: String
    let statusColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)

                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SoundEventSettingsLine: View {
    let event: NotificationEvent
    @Binding var isEnabled: Bool
    @Binding var selectedSound: NotificationSound
    let preview: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Text(event.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Picker(event.title, selection: $selectedSound) {
                    ForEach(NotificationSound.allCases, id: \.self) { sound in
                        Text(sound.rawValue).tag(sound)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
                .disabled(!isEnabled)

                Button(action: preview) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(isEnabled ? 0.82 : 0.4))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isEnabled ? 0.08 : 0.03))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct SoundPackEventLine: View {
    let event: NotificationEvent
    @Binding var isEnabled: Bool
    let preview: () -> Void

    private var categorySummary: String {
        event.cespCategories.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Text(event.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)

                Text(categorySummary)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))
            }

            Spacer(minLength: 12)

            Button(action: preview) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(isEnabled ? 0.82 : 0.4))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isEnabled ? 0.08 : 0.03))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
