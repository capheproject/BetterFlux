import SwiftUI

struct MenuView: View {
    @ObservedObject var c: Controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BetterFlux").font(.headline)

            Picker("", selection: $c.mode) {
                ForEach(WarmthMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Warmth sets the night temperature; flipped so dragging right makes it warmer.
            HStack {
                Image(systemName: "snowflake").foregroundStyle(.secondary).frame(width: 18)
                Slider(value: Binding(get: { 6500 + 1900 - c.nightTemp },
                                      set: { c.nightTemp = (6500 + 1900 - $0).rounded() }),
                       in: 1900...6500)
                Image(systemName: "flame").foregroundStyle(.secondary).frame(width: 18)
            }
            .disabled(c.mode == .off)

            HStack {
                Image(systemName: "sun.min").foregroundStyle(.secondary).frame(width: 18)
                Slider(value: $c.brightness, in: Controller.minBrightness...1)
                Image(systemName: "sun.max").foregroundStyle(.secondary).frame(width: 18)
            }

            HStack {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
    }
}

struct SettingsView: View {
    @ObservedObject var c: Controller

    var body: some View {
        Form {
            Section("Warmth") {
                slider("Night", value: $c.nightTemp, range: 1900...6500, step: 100, text: "\(Int(c.nightTemp))K")
                slider("Day", value: $c.dayTemp, range: 3400...6500, step: 100, text: "\(Int(c.dayTemp))K")
            }

            Section("Schedule") {
                DatePicker("Warm from", selection: time(\.eveningStart), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: time(\.morningEnd), displayedComponents: .hourAndMinute)
                slider("Fade", value: $c.transition, range: 0...180, step: 5,
                       text: c.transition == 0 ? "Instant" : "\(Int(c.transition)) min")
            }

            Section("Shortcuts") {
                LabeledContent("Dim / brighten", value: "⌃⌥⌘↓ / ⌃⌥⌘↑")
                LabeledContent("Full brightness", value: "⌃⌥⌘0")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(get: { c.launchAtLogin }, set: { c.launchAtLogin = $0 }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                        step: Double, text: String) -> some View {
        LabeledContent(label) {
            HStack {
                // Rounding here instead of passing `step` avoids the tick marks a stepped slider draws.
                Slider(value: Binding(get: { value.wrappedValue },
                                      set: { value.wrappedValue = ($0 / step).rounded() * step }),
                       in: range)
                    .labelsHidden()
                Text(text).monospacedDigit().foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func time(_ keyPath: ReferenceWritableKeyPath<Controller, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(c[keyPath: keyPath] * 60)) },
            set: {
                let d = Calendar.current.dateComponents([.hour, .minute], from: $0)
                c[keyPath: keyPath] = (d.hour ?? 0) * 60 + (d.minute ?? 0)
            }
        )
    }
}
