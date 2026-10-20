import AppKit
import SwiftUI
import UndertoneCore

/// Every setting, by page, with a live preview of the picture showing now under them. Every change applies straight
/// away and writes the config file.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(_ page: SettingsPage = .picture) {
        SettingsModel.shared.sync()
        if window == nil {
            let view = SettingsView(model: SettingsModel.shared, page: page)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Undertone"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.setContentSize(SettingsView.size)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case picture, effects, schedule, screen, title, motion, general

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .picture: "Picture"
        case .effects: "Effects"
        case .schedule: "Schedule"
        case .screen: "Screen"
        case .title: "Title"
        case .motion: "Lock Screen Motion"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .picture: "paintpalette"
        case .effects: "camera.filters"
        case .schedule: "clock.arrow.circlepath"
        case .screen: "macbook"
        case .title: "textformat"
        case .motion: "play.rectangle"
        case .general: "gearshape"
        }
    }
}

struct SettingsView: View {
    static let size = NSSize(width: 860, height: 640)

    @Bindable var model: SettingsModel
    @State var page: SettingsPage

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPage.allCases, selection: $page) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .frame(width: 200)
            Divider()
            VStack(spacing: 0) {
                Preview(model: model)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                Group {
                    switch page {
                    case .picture: PicturePage(model: model)
                    case .effects: EffectsPage(model: model)
                    case .schedule: SchedulePage(model: model)
                    case .screen: ScreenPage(model: model)
                    case .title: TitlePage(model: model)
                    case .motion: MotionPage(model: model)
                    case .general: GeneralPage()
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: Pictures

/// A recipe drawn small, from the cache when it can be (so the docs' images, drawn ahead, show at once).
struct RecipeImage: View {
    let key: Thumbnails.Key
    @State private var image: CGImage?

    init(_ recipe: Recipe, width: Int, height: Int, overlay: Overlay = Overlay()) {
        let key = Thumbnails.Key(recipe: recipe, width: width, height: height, overlay: overlay)
        self.key = key
        _image = State(initialValue: Thumbnails.drawImmediately ? Thumbnails.shared.image(key) : Thumbnails.shared
            .cached(key))
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(decorative: image, scale: 2).resizable()
            }
        }
        .frame(width: CGFloat(key.width), height: CGFloat(key.height))
        .task(id: key) {
            if let cached = Thumbnails.shared.cached(key) {
                image = cached
                return
            }
            let key = key
            image = await Task.detached(priority: .userInitiated) { Thumbnails.shared.image(key) }.value
        }
    }
}

/// The picture showing now, as the settings would draw it, with its name and Shuffle.
private struct Preview: View {
    let model: SettingsModel

    var body: some View {
        let recipe = model.recipe()
        HStack(alignment: .center, spacing: 20) {
            RecipeImage(recipe, width: 360, height: 234, overlay: overlay)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            VStack(alignment: .leading, spacing: 6) {
                Text("Showing now").font(.caption).foregroundStyle(.secondary)
                Text("\(recipe.style.rawValue.capitalized) in \(recipe.tonality.rawValue.capitalized)")
                    .font(.title2.weight(.semibold))
                Text(effectNames(recipe.effects)).foregroundStyle(.secondary)
                Button("Shuffle") { model.shuffle() }
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
    }

    /// The notch strip and corners at the preview's scale: a 14-inch MacBook Pro is 1512 points wide, the preview
    /// 360, drawn at twice that.
    private var overlay: Overlay {
        let factor: Float = 2 * 360 / 1512
        return Overlay(
            strip: model.settings.hideNotch ? Int(37 * factor) : 0,
            cornerRadius: model.settings.roundCorners ? Int(Overlay.windowCorner * factor) : 0
        )
    }

    private func effectNames(_ effects: Effects) -> String {
        var names = Effect.selectable.filter(effects.isOn).map(\.title)
        if effects.vignette != nil { names.insert("Vignette", at: 0) }
        if effects.grain != nil { names.append("Grain") }
        return names.isEmpty ? "No effects" : names.joined(separator: " · ")
    }
}

/// A grid of choices drawn as pictures: in shuffle mode each can be left out; in always mode one is chosen.
private struct ChoiceGrid<Value: Hashable & CaseIterable & RawRepresentable & Sendable>: View
    where Value.RawValue == String
{
    @Binding var selection: Selection<Value>
    let picture: (Value) -> Recipe

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(Value.allCases), id: \.self) { value in
                tile(value)
            }
        }
    }

    private func isChosen(_ value: Value) -> Bool {
        selection.mode == .always ? selection.always == value : !selection.never.contains(value)
    }

    private func tile(_ value: Value) -> some View {
        let chosen = isChosen(value)
        return Button {
            tap(value)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                RecipeImage(picture(value), width: 132, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(chosen ? Color.accentColor : .clear, lineWidth: 2.5)
                    )
                    .opacity(chosen ? 1 : 0.35)
                HStack(spacing: 4) {
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chosen ? Color.accentColor : .secondary)
                    Text(value.rawValue.capitalized)
                }
                .font(.callout)
            }
        }
        .buttonStyle(.plain)
    }

    private func tap(_ value: Value) {
        if selection.mode == .always {
            selection.always = value
        } else if selection.never.contains(value) {
            selection.never.remove(value)
        } else if selection.never.count < Value.allCases.count - 1 {
            // At least one stays in.
            selection.never.insert(value)
        }
    }
}

private struct PicturePage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        // The tiles show each style and tonality plainly: the effects are in the preview above.
        let current = model.recipe(effects: .standard)
        Form {
            Section {
                Picker("Style", selection: $model.settings.style.mode) {
                    Text("Shuffle").tag(Selection<Style>.Mode.shuffle)
                    Text("Always the same").tag(Selection<Style>.Mode.always)
                }
                .pickerStyle(.segmented)
                ChoiceGrid(selection: $model.settings.style) { style in
                    var recipe = current
                    recipe.style = style
                    return recipe
                }
            } footer: {
                Text(model.settings.style.mode == .shuffle
                    ? "Each shuffle picks a different checked style. Click one to leave it out."
                    : "Every picture is the chosen style; shuffles change its layout and the rest.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Tonality", selection: $model.settings.tonality.mode) {
                    Text("Shuffle").tag(Selection<Tonality>.Mode.shuffle)
                    Text("Always the same").tag(Selection<Tonality>.Mode.always)
                }
                .pickerStyle(.segmented)
                ChoiceGrid(selection: $model.settings.tonality) { tonality in
                    var recipe = current
                    recipe.tonality = tonality
                    return recipe
                }
            } footer: {
                Text("Every tonality has a light and a dark half; the picture follows your appearance.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Effects

private struct EffectsPage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        let base = model.recipe(effects: .none)
        Form {
            Section {
                EffectRow(
                    title: "Vignette", summary: "The corners darken a little", recipe: base, effects: vignetteOnly,
                    isOn: optional(\.vignette, default: 1)
                ) {
                    SliderRow("Strength", value: number(\.vignette, 1), in: 0 ... 3)
                }
                EffectRow(
                    title: "Grain", summary: "Fine film grain over everything", recipe: base, effects: grainOnly,
                    isOn: optional(\.grain, default: 0.035)
                ) {
                    SliderRow("Amount", value: number(\.grain, 0.035), in: 0 ... 0.12)
                }
            } header: {
                Text("On every picture")
            }
            Section {
                ForEach(Effect.selectable, id: \.self) { effect in
                    EffectRow(
                        title: effect.title, summary: effect.summary, recipe: base,
                        effects: Effects.none.with(effect).merging(model.settings.effects, for: effect),
                        isOn: toggle(effect)
                    ) {
                        parameters(effect)
                    }
                }
            } header: {
                Text("Effects")
            } footer: {
                Text(
                    "Effects apply in a fixed order: glass, halftone, vignette, bloom, posterize, paper, leak, dither, "
                        + "grain."
                )
                .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Add a random effect on each shuffle", isOn: $model.settings.randomEffect)
                if model.settings.randomEffect {
                    ForEach(Effect.selectable, id: \.self) { effect in
                        Toggle(effect.title, isOn: allowedInRandom(effect))
                            .padding(.leading, 16)
                    }
                }
            } header: {
                Text("Random")
            } footer: {
                Text("Chooses among the checked effects that are not already on, a different one each time.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var vignetteOnly: Effects {
        Effects(vignette: model.settings.effects.vignette ?? 1, grain: nil)
    }

    /// Grain shows better in a small picture a little stronger than it is.
    private var grainOnly: Effects {
        Effects(vignette: nil, grain: max(model.settings.effects.grain ?? 0.035, 0.06))
    }

    private func toggle(_ effect: Effect) -> Binding<Bool> {
        Binding(
            get: { model.settings.effects.isOn(effect) },
            set: { model.settings.effects.set(effect, on: $0) }
        )
    }

    private func allowedInRandom(_ effect: Effect) -> Binding<Bool> {
        Binding(
            get: { !model.settings.randomEffectNever.contains(effect) },
            set: { allowed in
                if allowed {
                    model.settings.randomEffectNever.remove(effect)
                } else {
                    model.settings.randomEffectNever.insert(effect)
                }
            }
        )
    }

    private func optional(_ path: WritableKeyPath<Effects, Float?>, default value: Float) -> Binding<Bool> {
        Binding(
            get: { model.settings.effects[keyPath: path] != nil },
            set: { model.settings.effects[keyPath: path] = $0 ? value : nil }
        )
    }

    private func number(_ path: WritableKeyPath<Effects, Float?>, _ fallback: Float) -> Binding<Float> {
        Binding(
            get: { model.settings.effects[keyPath: path] ?? fallback },
            set: { model.settings.effects[keyPath: path] = $0 }
        )
    }

    /// A binding to one setting of an effect that is on.
    private func parameter<E, V>(
        _ path: WritableKeyPath<Effects, E?>, _ field: WritableKeyPath<E, V>, _ fallback: E
    ) -> Binding<V> {
        Binding(
            get: { (model.settings.effects[keyPath: path] ?? fallback)[keyPath: field] },
            set: { value in
                var effect = model.settings.effects[keyPath: path] ?? fallback
                effect[keyPath: field] = value
                model.settings.effects[keyPath: path] = effect
            }
        )
    }

    private func whole(_ binding: Binding<Int>) -> Binding<Float> {
        Binding(get: { Float(binding.wrappedValue) }, set: { binding.wrappedValue = Int($0.rounded()) })
    }

    @ViewBuilder
    private func parameters(_ effect: Effect) -> some View {
        switch effect {
        case .dither:
            SliderRow("Levels", value: whole(parameter(\.dither, \.levels, .init())), in: 2 ... 16, step: 1)
            SliderRow("Cell", value: parameter(\.dither, \.cell, .init()), in: 1 ... 4, step: 1, unit: "pt")
        case .halftone:
            SliderRow("Spacing", value: parameter(\.halftone, \.spacing, .init()), in: 4 ... 24, unit: "pt")
            SliderRow("Angle", value: parameter(\.halftone, \.angle, .init()), in: 0 ... 90, unit: "°")
        case .glass:
            SliderRow("Width", value: parameter(\.glass, \.width, .init()), in: 12 ... 96, unit: "pt")
            SliderRow("Strength", value: parameter(\.glass, \.strength, .init()), in: 0 ... 0.9)
        case .bloom:
            SliderRow("Threshold", value: parameter(\.bloom, \.threshold, .init()), in: 0 ... 1)
            SliderRow("Strength", value: parameter(\.bloom, \.strength, .init()), in: 0 ... 1.5)
        case .leak:
            SliderRow("Strength", value: parameter(\.leak, \.strength, .init()), in: 0 ... 2)
            SliderRow("Warmth", value: parameter(\.leak, \.warmth, .init()), in: 0 ... 1)
        case .paper:
            SliderRow("Strength", value: parameter(\.paper, \.strength, .init()), in: 0 ... 2)
        case .posterize:
            SliderRow("Bands", value: whole(parameter(\.posterize, \.bands, .init())), in: 3 ... 16, step: 1)
        case .none:
            EmptyView()
        }
    }
}

extension Effects {
    /// This effect alone, with the settings it has in `settings` when it is on there.
    func merging(_ settings: Effects, for effect: Effect) -> Effects {
        var effects = self
        switch effect {
        case .dither: effects.dither = settings.dither ?? effects.dither
        case .halftone: effects.halftone = settings.halftone ?? effects.halftone
        case .glass: effects.glass = settings.glass ?? effects.glass
        case .bloom: effects.bloom = settings.bloom ?? effects.bloom
        case .leak: effects.leak = settings.leak ?? effects.leak
        case .paper: effects.paper = settings.paper ?? effects.paper
        case .posterize: effects.posterize = settings.posterize ?? effects.posterize
        case .none: break
        }
        return effects
    }
}

/// One effect: a small picture of it over the picture showing now, its name, its switch, and (when on) its settings.
private struct EffectRow<Parameters: View>: View {
    let title: String
    let summary: String
    let recipe: Recipe
    let effects: Effects
    @Binding var isOn: Bool
    @ViewBuilder let parameters: () -> Parameters

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RecipeImage(withEffects, width: 96, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
            }
            if isOn {
                parameters().padding(.leading, 108)
            }
        }
        .padding(.vertical, 2)
    }

    private var withEffects: Recipe {
        var recipe = recipe
        recipe.effects = effects
        return recipe
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float?
    var unit = ""

    init(_ title: String, value: Binding<Float>, in range: ClosedRange<Float>, step: Float? = nil, unit: String = "") {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
            Text(label).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
        }
        .font(.callout)
    }

    private var label: String {
        let number = step == 1 ? String(Int(value.rounded())) : String(format: value < 0.1 ? "%.3f" : "%.2f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

// MARK: The other pages

private struct SchedulePage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Shuffle", selection: $model.settings.interval) {
                    ForEach(ShuffleInterval.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Shuffle on login and wake", isOn: $model.settings.shuffleOnWake)
            } footer: {
                Text("Intervals count from the last shuffle, across sleep and restarts. Shuffle in the menu, or "
                    + "undertone shuffle, works any time.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ScreenPage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Spaces", selection: $model.settings.spaces) {
                    Text("The same picture everywhere").tag(SpacesMode.same)
                    Text("A picture per space").tag(SpacesMode.different)
                }
            } footer: {
                Text("A picture per space keeps the style and tonality and gives each space its own layout.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Hide the notch", isOn: $model.settings.hideNotch)
                Toggle("Round corners", isOn: $model.settings.roundCorners)
            } footer: {
                Text("The notch strip is drawn on displays with a notch. Rounded corners curve like macOS's windows, "
                    + "so a window tiled into a corner meets black.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TitlePage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle("Show a title", isOn: $model.settings.showText)
                TextField("Title", text: $model.settings.title)
                TextField("Subtitle", text: $model.settings.subtitle)
            } footer: {
                Text("{computer}, {user}, {os} and {host} are filled in.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct MotionPage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle("Lock screen motion", isOn: $model.settings.lockScreenMotion)
            } footer: {
                Text("Your picture drifts while the Mac is locked (with Undertone as your screen saver) and slows to "
                    + "a stop on the desktop as you unlock.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Speed", selection: $model.settings.motionSpeed) {
                    ForEach(MotionSpeed.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Movement", selection: $model.settings.motionMovement) {
                    ForEach(MotionMovement.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                SliderRow("Settle", value: $model.settings.settleSeconds, in: 1 ... 5, step: 0.5, unit: "s")
                Picker("Easing", selection: $model.settings.settleEasing) {
                    ForEach(Movie.Easing.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Button("Open Screen Saver Settings") { MotionStudio.openScreenSaverSettings() }
            } footer: {
                Text("Changes draw the movies again in the background, which takes a few minutes.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!model.settings.lockScreenMotion)
        }
    }
}

private struct GeneralPage: View {
    @State private var openAtLogin = LaunchAtLogin.isEnabled
    @State private var checks = Updater.shared.checksAutomatically
    @State private var installs = Updater.shared.installsAutomatically

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in LaunchAtLogin.set(on) }
            }
            Section {
                Toggle("Check for updates automatically", isOn: $checks)
                    .onChange(of: checks) { _, on in Updater.shared.checksAutomatically = on }
                Toggle("Install updates automatically", isOn: $installs)
                    .onChange(of: installs) { _, on in Updater.shared.installsAutomatically = on }
                Button("Check for Updates…") { Updater.shared.checkForUpdates() }
            } header: {
                Text("Updates")
            }
            .disabled(!Updater.shared.isRunning)
            Section {
                LabeledContent("File", value: Preferences.configURL.path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                ))
                HStack {
                    Button("Open Config File") { AppDelegate.openConfigFile() }
                    Button("Show in Finder") { AppDelegate.openConfigFile(reveal: true) }
                }
            } header: {
                Text("Config file")
            } footer: {
                Text("Every setting here is also in this file, for your dotfiles. Edits to it apply on their own.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
