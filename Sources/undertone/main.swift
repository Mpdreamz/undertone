import Foundation
import UndertoneCore

// undertone: Undertone from a shell or a hotkey daemon. It starts in milliseconds and needs no permission.

let usage = """
usage: undertone render [--style S] [--tonality T] [--appearance dark|light] [--seed N] [--grain G] [--effect E]
                        [--size WxH] [--scale K] [--strip PT] [--corners PT] [--title T] [--subtitle T]
                        -o <file.png|file.jpg>
       undertone shuffle
       undertone movie [render options] [--seconds S] [--fps N] [--settle S] [--movement M]
                       [--easing glide|easeOut|spring] [--codec hevc|h264] -o <file.mp4>
       undertone config [--defaults | --check [file]]
       undertone styles
       undertone tonalities
       undertone effects
       undertone --version

  shuffle
      A new picture now, in Undertone.app (which must be running), as the menu's Shuffle.
  movie
      The same picture in motion: one seamless loop (--seconds, default 12, at --fps, default 30), then a settle
      (--settle, default 2.5 seconds; 0 for none) that slows it to a stop on the still picture, as --easing says
      (default easeOut). --movement scales how far things move (default 1; 0.5 is subtle, 1.6 strong).
  config
      Where the config file is (~/.config/undertone/config.toml, or under $XDG_CONFIG_HOME). --defaults prints a
      file with every setting at its default, to start from; --check reads the file (or the one given) and lists
      what it cannot use, failing when there is anything.
  render
      Draw one picture to a PNG (a JPEG when the file ends in .jpg), without the app. --size is in pixels
      (default 3024x1964, a 14" MacBook Pro), --scale the pixels to a point (default 2). Defaults: mesh, ember, dark, seed 1, grain 0.035.
      --strip draws the black notch strip that tall, --corners rounds the corners below it, both in points.
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("undertone: \(message)\n".utf8))
    exit(code)
}

func parse<T>(_ value: T?, _ message: String) -> T {
    guard let value else { fail(message) }
    return value
}

func render(_ arguments: ArraySlice<String>, movie: Bool = false) {
    var recipe = Recipe(style: .mesh, tonality: .ember, appearance: .dark, seed: 1)
    var width = 3024, height = 1964
    var scale: Float = 2
    var output: String?
    var strip: Float = 0, corners: Float = 0
    var title = "", subtitle = ""
    var seconds = 12.0, fps = 30, settle = 2.5
    var codec = Movie.Codec.hevc
    var movement: Float = 1, easing = Movie.Easing.easeOut
    var rest = arguments
    while let flag = rest.popFirst() {
        guard let value = rest.popFirst() else { fail("\(flag) needs a value") }
        switch flag {
        case "--style": recipe.style = parse(Style(rawValue: value), "no style \(value) (see undertone styles)")
        case "--tonality":
            recipe.tonality = parse(Tonality(rawValue: value), "no tonality \(value) (see undertone tonalities)")
        case "--appearance": recipe.appearance = parse(Appearance(rawValue: value), "appearance is dark or light")
        case "--seed": recipe.seed = parse(UInt64(value), "seed is a whole number")
        case "--effect": recipe.effect = parse(Effect(rawValue: value), "no effect \(value) (see undertone effects)")
        case "--grain": recipe.grain = parse(Float(value), "grain is a number, e.g. 0.035")
        case "--scale": scale = parse(Float(value), "scale is a number, e.g. 2")
        case "--size":
            let parts = value.split(separator: "x").compactMap { Int($0) }
            guard parts.count == 2, parts.allSatisfy({ $0 > 0 }) else { fail("size is WxH, e.g. 3024x1964") }
            (width, height) = (parts[0], parts[1])
        case "--strip": strip = parse(Float(value), "strip is in points, e.g. 37")
        case "--corners": corners = parse(Float(value), "corners is in points, e.g. 10")
        case "--title": title = value
        case "--subtitle": subtitle = value
        case "--seconds" where movie: seconds = parse(Double(value), "seconds is a number, e.g. 12")
        case "--fps" where movie: fps = parse(Int(value), "fps is a whole number, e.g. 30")
        case "--settle" where movie: settle = parse(Double(value), "settle is in seconds, e.g. 2.5")
        case "--movement" where movie: movement = parse(Float(value), "movement is a number, e.g. 1")
        case "--easing" where movie: easing = parse(Movie.Easing(rawValue: value), "easing is glide, easeOut or spring")
        case "--codec" where movie: codec = parse(Movie.Codec(rawValue: value), "codec is hevc or h264")
        case "-o", "--output": output = value
        default: fail("unknown option \(flag)\n\(usage)", code: 2)
        }
    }
    guard let output else { fail("\(movie ? "movie" : "render") needs -o <file>", code: 2) }
    if movie {
        var motions = Movie.loop(seconds: seconds, fps: fps, movement: movement)
        if settle > 0 {
            motions += Movie.settle(
                from: 0, loopSeconds: seconds, seconds: settle, fps: fps, movement: movement, easing: easing
            )
        }
        do {
            try Movie.write(
                recipe, width: width, height: height, scale: scale, motions: motions, fps: fps, codec: codec,
                to: URL(fileURLWithPath: output)
            ) { written in
                if written % fps == 0 || written == motions.count {
                    FileHandle.standardError.write(Data("\rundertone: \(written)/\(motions.count) frames".utf8))
                }
            }
            FileHandle.standardError.write(Data("\n".utf8))
        } catch { fail("could not write \(output): \(error)") }
        return
    }
    let picture = Renderer.render(recipe, width: width, height: height, scale: scale)
    let overlay = Overlay(
        strip: Int((strip * scale).rounded()), cornerRadius: Int((corners * scale).rounded()),
        title: title, subtitle: subtitle, scale: scale
    )
    let jpeg = [".jpg", ".jpeg"].contains { output.lowercased().hasSuffix($0) }
    guard let image = Composer.compose(picture, overlay, appearance: recipe.appearance),
          let data = jpeg ? Composer.jpeg(image) : Composer.png(image)
    else { fail("could not encode the picture") }
    do { try data.write(to: URL(fileURLWithPath: output)) } catch { fail("could not write \(output): \(error)") }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "render":
    render(arguments.dropFirst())
case "movie":
    render(arguments.dropFirst(), movie: true)
case "shuffle":
    DistributedNotificationCenter.default().postNotificationName(
        .init("io.github.mpdreamz.undertone.shuffle"), object: nil, userInfo: nil, deliverImmediately: true
    )
case "config":
    switch arguments.dropFirst().first {
    case nil:
        print(ConfigFile.url().path)
    case "--defaults":
        print(ConfigFile.render(Settings()), terminator: "")
    case "--check":
        let url = arguments.count > 2 ? URL(fileURLWithPath: arguments[2]) : ConfigFile.url()
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { fail("cannot read \(url.path)") }
        let warnings = ConfigFile.parse(text).warnings
        if warnings.isEmpty {
            print("\(url.path): fine")
        } else {
            for warning in warnings {
                print("\(url.path):\(warning.line): \(warning.message)")
            }
            exit(1)
        }
    default:
        fail("config takes --defaults or --check [file]", code: 2)
    }
case "styles":
    for style in Style.allCases {
        print("\(style.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))\(style.summary)")
    }
case "effects":
    for effect in Effect.allCases {
        print("\(effect.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))\(effect.summary)")
    }
case "tonalities":
    print(Tonality.allCases.map(\.rawValue).joined(separator: "\n"))
case "--version", "-v":
    let app = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
    let info = (NSDictionary(contentsOf: app) as? [String: Any]) ?? [:]
    print(BuildInfo(info: info).label)
case "--help", "-h", nil:
    print(usage)
default:
    fail("unknown command \(arguments[0])\n\(usage)", code: 2)
}
