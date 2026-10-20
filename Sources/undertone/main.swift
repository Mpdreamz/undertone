import Foundation
import UndertoneCore

// undertone: Undertone from a shell or a hotkey daemon. It starts in milliseconds and needs no permission.

let usage = """
usage: undertone render [--style S] [--tonality T] [--appearance dark|light] [--seed N] [--grain G]
                        [--size WxH] [--scale K] -o <file.png>
       undertone styles
       undertone tonalities
       undertone --version

  render
      Draw one picture to a PNG, without the app: --size is in pixels (default 3024x1964, a 14" MacBook Pro),
      --scale the pixels to a point (default 2). Defaults: mesh, ember, dark, seed 1, grain 0.035.
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("undertone: \(message)\n".utf8))
    exit(code)
}

func parse<T>(_ value: T?, _ message: String) -> T {
    guard let value else { fail(message) }
    return value
}

func render(_ arguments: ArraySlice<String>) {
    var recipe = Recipe(style: .mesh, tonality: .ember, appearance: .dark, seed: 1)
    var width = 3024, height = 1964
    var scale: Float = 2
    var output: String?
    var rest = arguments
    while let flag = rest.popFirst() {
        guard let value = rest.popFirst() else { fail("\(flag) needs a value") }
        switch flag {
        case "--style": recipe.style = parse(Style(rawValue: value), "no style \(value) (see undertone styles)")
        case "--tonality":
            recipe.tonality = parse(Tonality(rawValue: value), "no tonality \(value) (see undertone tonalities)")
        case "--appearance": recipe.appearance = parse(Appearance(rawValue: value), "appearance is dark or light")
        case "--seed": recipe.seed = parse(UInt64(value), "seed is a whole number")
        case "--grain": recipe.grain = parse(Float(value), "grain is a number, e.g. 0.035")
        case "--scale": scale = parse(Float(value), "scale is a number, e.g. 2")
        case "--size":
            let parts = value.split(separator: "x").compactMap { Int($0) }
            guard parts.count == 2, parts.allSatisfy({ $0 > 0 }) else { fail("size is WxH, e.g. 3024x1964") }
            (width, height) = (parts[0], parts[1])
        case "-o", "--output": output = value
        default: fail("unknown option \(flag)\n\(usage)", code: 2)
        }
    }
    guard let output else { fail("render needs -o <file.png>", code: 2) }
    let picture = Renderer.render(recipe, width: width, height: height, scale: scale)
    guard let png = picture.png() else { fail("could not encode the PNG") }
    do { try png.write(to: URL(fileURLWithPath: output)) } catch { fail("could not write \(output): \(error)") }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "render":
    render(arguments.dropFirst())
case "styles":
    for style in Style.allCases {
        print("\(style.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))\(style.summary)")
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
