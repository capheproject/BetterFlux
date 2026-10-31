import AppKit
import Combine
import ServiceManagement

enum WarmthMode: String, CaseIterable, Identifiable {
    case schedule, always, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .schedule: return "Schedule"
        case .always: return "Always"
        case .off: return "Off"
        }
    }
}

final class Controller: ObservableObject {
    static let shared = Controller()

    private let defaults = UserDefaults.standard

    @Published var mode: WarmthMode { didSet { save(mode.rawValue, "mode"); apply() } }
    @Published var dayTemp: Double { didSet { save(dayTemp, "dayTemp"); apply() } }
    @Published var nightTemp: Double { didSet { save(nightTemp, "nightTemp"); apply() } }
    /// Minutes after midnight when the evening warm-up starts.
    @Published var eveningStart: Int { didSet { save(eveningStart, "eveningStart"); apply() } }
    /// Minutes after midnight when the morning cool-down is finished.
    @Published var morningEnd: Int { didSet { save(morningEnd, "morningEnd"); apply() } }
    @Published var transition: Double { didSet { save(transition, "transition"); apply() } }
    /// 1 = normal, lower = dimmer than the hardware minimum allows.
    @Published var brightness: Double { didSet { save(brightness, "brightness"); apply() } }

    @Published private(set) var currentTemp: Double = 6500
    @Published private(set) var nightAmount: Double = 0

    static let minBrightness = 0.05
    private var timer: Timer?

    private init() {
        defaults.register(defaults: [
            "mode": WarmthMode.schedule.rawValue,
            "dayTemp": 6500.0,
            "nightTemp": 3400.0,
            "eveningStart": 19 * 60 + 30,
            "morningEnd": 7 * 60,
            "transition": 60.0,
            "brightness": 1.0,
        ])
        mode = WarmthMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .schedule
        dayTemp = defaults.double(forKey: "dayTemp")
        nightTemp = defaults.double(forKey: "nightTemp")
        eveningStart = defaults.integer(forKey: "eveningStart")
        morningEnd = defaults.integer(forKey: "morningEnd")
        transition = defaults.double(forKey: "transition")
        brightness = max(Self.minBrightness, defaults.double(forKey: "brightness"))
    }

    func start() {
        Gamma.capture()
        apply()

        // Gamma tables get reset by sleep, lock, display changes and other apps, so reapply often.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.apply() }

        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.recapture() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.recapture() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.recapture() }
    }

    private func recapture() {
        // Give the system a moment to settle its own tables before reading them.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Gamma.capture()
            self.apply()
        }
    }

    func apply() {
        let amount: Double
        switch mode {
        case .off: amount = 0
        case .always: amount = 1
        case .schedule: amount = scheduleAmount(at: Date())
        }
        nightAmount = amount

        // Interpolate in mireds so the change looks perceptually even.
        let day = 1_000_000 / dayTemp, night = 1_000_000 / nightTemp
        currentTemp = 1_000_000 / (day + (night - day) * amount)

        let (r, g, b) = ColorTemperature.rgb(kelvin: currentTemp)
        Gamma.apply(red: r, green: g, blue: b, brightness: brightness)
    }

    /// 0 during the day, 1 at night, ramping across the transition at each end.
    func scheduleAmount(at date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let now = Double(comps.hour! * 60 + comps.minute!) + Double(comps.second!) / 60
        func wrap(_ v: Double) -> Double { (v.truncatingRemainder(dividingBy: 1440) + 1440).truncatingRemainder(dividingBy: 1440) }
        let sinceStart = wrap(now - Double(eveningStart))
        let nightLength = wrap(Double(morningEnd - eveningStart))
        guard sinceStart < nightLength else { return 0 }
        guard transition > 0 else { return 1 }
        let ramp = min(transition, nightLength / 2)
        return min(1, sinceStart / ramp, (nightLength - sinceStart) / ramp)
    }

    func nudgeBrightness(_ delta: Double) {
        brightness = min(1, max(Self.minBrightness, (brightness + delta * 100).rounded() / 100))
    }

    var iconName: String {
        if brightness < 0.995 && nightAmount < 0.5 { return "sun.min" }
        return nightAmount >= 0.5 ? "moon.fill" : "sun.max"
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("BetterFlux: launch at login failed: \(error)")
            }
        }
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
}
