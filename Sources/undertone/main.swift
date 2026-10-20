import Foundation
import UndertoneCore

// undertone: Undertone from a shell or a hotkey daemon. It starts in milliseconds and needs no permission.

let usage = """
usage: undertone --version
       undertone --help
"""

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "--version", "-v":
    let app = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
    let info = (NSDictionary(contentsOf: app) as? [String: Any]) ?? [:]
    print(BuildInfo(info: info).label)
case "--help", "-h", nil:
    print(usage)
default:
    FileHandle.standardError.write(Data("undertone: unknown command \(arguments[0])\n\(usage)\n".utf8))
    exit(2)
}
