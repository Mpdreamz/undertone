import AppKit
import SwiftUI
import UndertoneCore

/// Everything the menu has, plus what a menu cannot hold: the title's text, motion timing and the grain's
/// strength. Every change applies straight away.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(
                settings: Desktop.shared.settings, onChange: { next in Desktop.shared.update { $0 = next } }
            )))
            window.title = "Undertone"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @State var settings: UndertoneCore.Settings
    var onChange: @MainActor (UndertoneCore.Settings) -> Void

    var body: some View {
        Form {
            Section("Picture") {
                Picker("Style", selection: $settings.style) {
                    Text("Random").tag(Choice<Style>.random)
                    Divider()
                    ForEach(Style.allCases, id: \.self) { style in
                        Text(style.rawValue.capitalized).tag(Choice<Style>.locked(style))
                    }
                }
                Picker("Tonality", selection: $settings.tonality) {
                    Text("Random").tag(Choice<Tonality>.random)
                    Divider()
                    ForEach(Tonality.allCases, id: \.self) { tonality in
                        Text(tonality.rawValue.capitalized).tag(Choice<Tonality>.locked(tonality))
                    }
                }
                Picker("Effect", selection: $settings.effect) {
                    Text("Random").tag(Choice<Effect>.random)
                    Divider()
                    ForEach(Effect.allCases, id: \.self) { effect in
                        Text(effect.title).tag(Choice<Effect>.locked(effect))
                    }
                }
                Picker("Spaces", selection: $settings.spaces) {
                    Text("A picture per space").tag(SpacesMode.different)
                    Text("The same picture everywhere").tag(SpacesMode.same)
                }
                Picker("Shuffle", selection: $settings.interval) {
                    ForEach(ShuffleInterval.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Shuffle on login and wake", isOn: $settings.shuffleOnWake)
                LabeledContent("Grain") {
                    Slider(value: $settings.grain, in: 0 ... 0.08)
                }
            }
            Section("Screen") {
                Toggle("Hide the notch", isOn: $settings.hideNotch)
                Toggle("Round corners", isOn: $settings.roundCorners)
            }
            Section {
                Picker("Speed", selection: $settings.motionSpeed) {
                    ForEach(MotionSpeed.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Movement", selection: $settings.motionMovement) {
                    ForEach(MotionMovement.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                LabeledContent("Settle") {
                    HStack {
                        Slider(value: $settings.settleSeconds, in: 1 ... 5, step: 0.5)
                        Text(String(format: "%.1f s", settings.settleSeconds))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Easing", selection: $settings.settleEasing) {
                    ForEach(Movie.Easing.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Lock Screen Motion")
            } footer: {
                Text(settings.lockScreenMotion
                    ? "Changes draw the movies again in the background, which takes a few minutes."
                    : "Turn on Lock Screen Motion in the menu to use these.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.lockScreenMotion)
            Section {
                Toggle("Show a title", isOn: $settings.showText)
                TextField("Title", text: $settings.title)
                TextField("Subtitle", text: $settings.subtitle)
            } header: {
                Text("Title")
            } footer: {
                Text("{computer}, {user}, {os} and {host} are filled in.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.showText)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .onChange(of: settings) { _, next in
            onChange(next)
        }
    }
}
