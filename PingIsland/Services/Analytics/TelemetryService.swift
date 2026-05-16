import Foundation
import os.log

enum TelemetryConsent {
    nonisolated static let analyticsEnabledKey = "analyticsEnabled"
    nonisolated static let anonymousIDKey = "analyticsAnonymousID"
}

struct TelemetryConfiguration: Equatable, Sendable {
    let slsHost: String
    let project: String
    let logstore: String
    let topic: String
    let source: String
    let dailyEventLimit: Int

    nonisolated var isEnabled: Bool {
        !slsHost.isEmpty && !project.isEmpty && !logstore.isEmpty
    }

    nonisolated var endpointURL: URL? {
        guard isEnabled else { return nil }
        return URL(string: "https://\(project).\(slsHost)/logstores/\(logstore)/track")
    }

    nonisolated init(
        slsHost: String,
        project: String = "ping-island",
        logstore: String = "ping-island",
        topic: String = "product-telemetry",
        source: String = "ping-island-macos",
        dailyEventLimit: Int = 200
    ) {
        self.slsHost = Self.normalizedHost(slsHost)
        self.project = project.trimmingCharacters(in: .whitespacesAndNewlines)
        self.logstore = logstore.trimmingCharacters(in: .whitespacesAndNewlines)
        self.topic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dailyEventLimit = max(0, dailyEventLimit)
    }

    nonisolated init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let dailyLimitRaw = infoDictionary["PINGTelemetryDailyEventLimit"] as? String
        self.init(
            slsHost: infoDictionary["PINGTelemetrySLSHost"] as? String ?? "",
            project: infoDictionary["PINGTelemetrySLSProject"] as? String ?? "ping-island",
            logstore: infoDictionary["PINGTelemetrySLSLogstore"] as? String ?? "ping-island",
            topic: infoDictionary["PINGTelemetrySLSTopic"] as? String ?? "product-telemetry",
            source: infoDictionary["PINGTelemetrySLSSource"] as? String ?? "ping-island-macos",
            dailyEventLimit: Int(dailyLimitRaw ?? "") ?? 200
        )
    }

    private nonisolated static func normalizedHost(_ value: String) -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("https://") {
            host.removeFirst("https://".count)
        } else if host.hasPrefix("http://") {
            host.removeFirst("http://".count)
        }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum TelemetryEventName: String, CaseIterable, Sendable {
    case appLaunched = "app_launched"
    case telemetryPreferenceChanged = "telemetry_preference_changed"
    case settingChanged = "setting_changed"
    case hookInstallCompleted = "hook_install_completed"
    case hookReinstallCompleted = "hook_reinstall_completed"
    case integrationStatusSnapshot = "integration_status_snapshot"
    case sessionDetected = "session_detected"
    case sessionCompleted = "session_completed"
}

struct TelemetryRecord: Codable, Equatable, Sendable {
    let fields: [String: String]
}

protocol TelemetrySink: Sendable {
    nonisolated func send(_ records: [TelemetryRecord], configuration: TelemetryConfiguration) async throws
}

struct SLSTelemetrySink: TelemetrySink {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func send(_ records: [TelemetryRecord], configuration: TelemetryConfiguration) async throws {
        guard let url = configuration.endpointURL, !records.isEmpty else { return }

        let payload: [String: Any] = [
            "__topic__": configuration.topic,
            "__source__": configuration.source,
            "__logs__": records.map(\.fields),
            "__tags__": [
                "app": "ping-island",
                "schema": "1"
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("0.6.0", forHTTPHeaderField: "x-log-apiversion")
        request.setValue("\(body.count)", forHTTPHeaderField: "x-log-bodyrawsize")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TelemetryError.uploadFailed
        }
    }
}

enum TelemetryError: Error {
    case uploadFailed
}

actor TelemetryService {
    static let shared = TelemetryService()

    private static let logger = Logger(subsystem: "com.wudanwu.pingisland", category: "Telemetry")

    private let configuration: TelemetryConfiguration
    private let defaults: UserDefaults
    private let sink: TelemetrySink
    private let calendar: Calendar
    private let flushIntervalNs: UInt64
    private let maxBatchSize: Int
    private let maxQueueSize: Int

    private var queue: [TelemetryRecord] = []
    private var flushLoop: Task<Void, Never>?
    private var recordedSessionIDs: Set<String> = []

    init(
        configuration: TelemetryConfiguration = TelemetryConfiguration(),
        defaults: UserDefaults = .standard,
        sink: TelemetrySink = SLSTelemetrySink(),
        calendar: Calendar = .current,
        flushIntervalNs: UInt64 = 60_000_000_000,
        maxBatchSize: Int = 10,
        maxQueueSize: Int = 200
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.sink = sink
        self.calendar = calendar
        self.flushIntervalNs = flushIntervalNs
        self.maxBatchSize = max(1, maxBatchSize)
        self.maxQueueSize = max(1, maxQueueSize)
    }

    func start() {
        guard isTelemetryActive else { return }
        guard flushLoop == nil else { return }
        flushLoop = Task { [flushIntervalNs] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: flushIntervalNs)
                await flush()
            }
        }
    }

    func stop() async {
        flushLoop?.cancel()
        flushLoop = nil
        await flush()
    }

    func handleConsentChanged(enabled: Bool) async {
        if enabled {
            start()
            await record(.telemetryPreferenceChanged, properties: ["enabled": "true"])
        } else {
            queue.removeAll()
            recordedSessionIDs.removeAll()
            defaults.removeObject(forKey: TelemetryConsent.anonymousIDKey)
        }
    }

    func record(
        _ name: TelemetryEventName,
        properties: [String: String] = [:],
        minimumInterval: TimeInterval = 0,
        throttleKey: String? = nil
    ) async {
        guard isTelemetryActive else { return }
        guard shouldAcceptEvent(name, minimumInterval: minimumInterval, throttleKey: throttleKey) else { return }
        guard consumeDailyBudget() else { return }

        let fields = sanitizedFields(
            name: name,
            properties: properties.merging(commonFields(), uniquingKeysWith: { current, _ in current })
        )
        guard !fields.isEmpty else { return }

        queue.append(TelemetryRecord(fields: fields))
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
        }
        if queue.count >= maxBatchSize {
            await flush()
        }
    }

    func recordAppLaunch() async {
        await record(
            .appLaunched,
            properties: [
                "auto_update_enabled": defaults.bool(forKey: "automaticUpdateChecksEnabled").description,
                "show_usage": defaults.bool(forKey: "showUsage").description
            ],
            minimumInterval: 6 * 60 * 60,
            throttleKey: "app_launch"
        )
    }

    func recordIntegrationSnapshot() async {
        let installedProfiles = await MainActor.run {
            ClientProfileRegistry.managedHookProfiles.filter { HookInstaller.isInstalled($0) }
        }
        await record(
            .integrationStatusSnapshot,
            properties: [
                "installed_count": "\(installedProfiles.count)",
                "enabled_clients": installedProfiles.map(\.id).sorted().joined(separator: ",")
            ],
            minimumInterval: 12 * 60 * 60,
            throttleKey: "integration_status_snapshot"
        )
    }

    func recordHookInstall(profileID: String, result: Bool, source: String) async {
        await record(
            .hookInstallCompleted,
            properties: [
                "client": sanitizedClientID(profileID),
                "result": result ? "success" : "failed",
                "source": source
            ],
            minimumInterval: 60,
            throttleKey: "hook_install:\(profileID):\(result)"
        )
    }

    func recordHookReinstall(profileID: String, result: Bool) async {
        await record(
            .hookReinstallCompleted,
            properties: [
                "client": sanitizedClientID(profileID),
                "result": result ? "success" : "failed"
            ],
            minimumInterval: 60,
            throttleKey: "hook_reinstall:\(profileID):\(result)"
        )
    }

    func recordSessionDetected(_ session: SessionState) async {
        guard recordedSessionIDs.insert(session.sessionId).inserted else { return }
        trimRecordedSessionIDsIfNeeded()
        await record(
            .sessionDetected,
            properties: [
                "client": safeClientID(for: session),
                "provider": session.provider.rawValue,
                "ingress": session.ingress.rawValue
            ]
        )
    }

    func recordSessionCompleted(_ session: SessionState) async {
        await record(
            .sessionCompleted,
            properties: [
                "client": safeClientID(for: session),
                "provider": session.provider.rawValue,
                "ingress": session.ingress.rawValue,
                "duration_bucket": durationBucket(Date().timeIntervalSince(session.createdAt)),
                "tool_count_bucket": countBucket(session.toolTracker.seenIds.count),
                "had_attention_request": (session.intervention != nil).description
            ],
            minimumInterval: 60,
            throttleKey: "session_completed:\(session.sessionId)"
        )
    }

    func flush() async {
        guard isTelemetryActive, !queue.isEmpty else { return }
        let batch = Array(queue.prefix(maxBatchSize))
        do {
            try await sink.send(batch, configuration: configuration)
            queue.removeFirst(batch.count)
        } catch {
            Self.logger.debug("Telemetry upload skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var isTelemetryActive: Bool {
        defaults.bool(forKey: TelemetryConsent.analyticsEnabledKey) && configuration.isEnabled
    }

    private func commonFields() -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            "schema_version": "1",
            "app_version": info["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": info["CFBundleVersion"] as? String ?? "unknown",
            "distribution_channel": distributionChannel,
            "macos_major": Foundation.ProcessInfo.processInfo.operatingSystemVersion.majorVersion.description,
            "arch": architecture,
            "language": languageBucket(),
            "surface_mode": defaults.string(forKey: AppSettingsDefaultKeys.surfaceMode) ?? "notch",
            "anonymous_user_id": anonymousID()
        ]
    }

    private var distributionChannel: String {
#if APP_STORE
        "app_store"
#else
        "github_release"
#endif
    }

    private var architecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }

    private func languageBucket() -> String {
        let raw = defaults.string(forKey: "appLanguage") ?? "system"
        if raw == AppLanguage.simplifiedChinese.rawValue {
            return "zh-Hans"
        }
        if raw == AppLanguage.english.rawValue {
            return "en"
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("zh") {
            return "zh-Hans"
        }
        if preferred.hasPrefix("en") {
            return "en"
        }
        return "other"
    }

    private func anonymousID() -> String {
        if let existing = defaults.string(forKey: TelemetryConsent.anonymousIDKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: TelemetryConsent.anonymousIDKey)
        return id
    }

    private func sanitizedFields(name: TelemetryEventName, properties: [String: String]) -> [String: String] {
        let allowedKeys = Self.allowedProperties(for: name).union(Self.commonPropertyKeys)
        var output: [String: String] = ["event": name.rawValue]
        for (key, value) in properties where allowedKeys.contains(key) {
            output[key] = Self.sanitizedValue(value)
        }
        return output
    }

    private nonisolated static let commonPropertyKeys: Set<String> = [
        "schema_version",
        "app_version",
        "build_number",
        "distribution_channel",
        "macos_major",
        "arch",
        "language",
        "surface_mode",
        "anonymous_user_id"
    ]

    private nonisolated static func allowedProperties(for name: TelemetryEventName) -> Set<String> {
        switch name {
        case .appLaunched:
            return ["auto_update_enabled", "show_usage"]
        case .telemetryPreferenceChanged:
            return ["enabled"]
        case .settingChanged:
            return ["setting_key", "value"]
        case .hookInstallCompleted, .hookReinstallCompleted:
            return ["client", "result", "source"]
        case .integrationStatusSnapshot:
            return ["installed_count", "enabled_clients"]
        case .sessionDetected:
            return ["client", "provider", "ingress"]
        case .sessionCompleted:
            return ["client", "provider", "ingress", "duration_bucket", "tool_count_bucket", "had_attention_request"]
        }
    }

    private nonisolated static func sanitizedValue(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._,:;|+-= ")
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(scalars).prefix(160).description
    }

    private func safeClientID(for session: SessionState) -> String {
        if let profileID = session.clientInfo.profileID {
            return sanitizedClientID(profileID)
        }
        return session.clientInfo.kind.rawValue
    }

    private func sanitizedClientID(_ value: String) -> String {
        Self.sanitizedValue(value.lowercased())
    }

    private func durationBucket(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "lt_1m"
        }
        if duration < 5 * 60 {
            return "1_5m"
        }
        if duration < 15 * 60 {
            return "5_15m"
        }
        if duration < 60 * 60 {
            return "15_60m"
        }
        return "gt_60m"
    }

    private func countBucket(_ count: Int) -> String {
        switch count {
        case 0:
            return "0"
        case 1...3:
            return "1_3"
        case 4...10:
            return "4_10"
        case 11...30:
            return "11_30"
        default:
            return "gt_30"
        }
    }

    private func shouldAcceptEvent(
        _ name: TelemetryEventName,
        minimumInterval: TimeInterval,
        throttleKey: String?
    ) -> Bool {
        guard minimumInterval > 0 else { return true }
        let key = "telemetryThrottle.\(throttleKey ?? name.rawValue)"
        let now = Date().timeIntervalSince1970
        let last = defaults.double(forKey: key)
        guard last == 0 || now - last >= minimumInterval else { return false }
        defaults.set(now, forKey: key)
        return true
    }

    private func consumeDailyBudget(now: Date = Date()) -> Bool {
        guard configuration.dailyEventLimit > 0 else { return false }
        let bucket = dailyBucket(for: now)
        let storedBucket = defaults.string(forKey: "telemetryDailyBucket")
        var count = storedBucket == bucket ? defaults.integer(forKey: "telemetryDailyCount") : 0
        guard count < configuration.dailyEventLimit else { return false }
        count += 1
        defaults.set(bucket, forKey: "telemetryDailyBucket")
        defaults.set(count, forKey: "telemetryDailyCount")
        return true
    }

    private func dailyBucket(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func trimRecordedSessionIDsIfNeeded() {
        guard recordedSessionIDs.count > 500 else { return }
        recordedSessionIDs.removeAll(keepingCapacity: true)
    }
}
