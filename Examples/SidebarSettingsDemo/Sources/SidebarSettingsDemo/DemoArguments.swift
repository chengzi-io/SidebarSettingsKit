import AppKit
import Darwin
import Foundation
import SidebarSettingsKit

/// What the demo's command line asks for: how the sidebar looks, in which appearance, and which
/// scenario to open.
struct DemoArguments: Sendable, Equatable {
    /// How the sidebar draws the pages' icons.
    var icons = Icons.plain

    /// The appearance the app forces; `nil` keeps the system's.
    var appearance: Appearance?

    /// The scenario to open on launch; `nil` shows the main window alone.
    var scenario: Scenario?

    /// A file to write the settings window's number to, for `screencapture -l`.
    var windowIDFile: String?

    /// The name of a ``SidebarSettingsConfiguration/Icons`` choice.
    enum Icons: String, Sendable, CaseIterable {
        case plain
        case tiled
    }

    /// The name of an `NSAppearance`.
    enum Appearance: String, Sendable, CaseIterable {
        case light
        case dark
    }
}

extension DemoArguments {
    /// A command line the demo cannot run.
    enum ParseError: Error, Equatable {
        case unknownOption(String)
        case missingValue(option: String)
        case unknownValue(option: String, value: String)
    }

    /// The arguments in `arguments`, whose first element is the executable's path.
    static func parse(_ arguments: [String]) throws -> DemoArguments {
        var result = DemoArguments()
        var index = 1
        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--icons":
                let raw = try value(of: option, in: arguments, at: &index)
                guard let icons = Icons(rawValue: raw) else {
                    throw ParseError.unknownValue(option: option, value: raw)
                }
                result.icons = icons
            case "--appearance":
                let raw = try value(of: option, in: arguments, at: &index)
                guard let appearance = Appearance(rawValue: raw) else {
                    throw ParseError.unknownValue(option: option, value: raw)
                }
                result.appearance = appearance
            case "--scenario":
                let raw = try value(of: option, in: arguments, at: &index)
                guard let scenario = Scenario(rawValue: raw) else {
                    throw ParseError.unknownValue(option: option, value: raw)
                }
                result.scenario = scenario
            case "--window-id-file":
                result.windowIDFile = try value(of: option, in: arguments, at: &index)
            default:
                guard option.hasPrefix("-"), !option.hasPrefix("--") else {
                    throw ParseError.unknownOption(option)
                }
                // A default in the argument domain, such as `-AppleLanguages (zh-Hans)` for
                // scenario 7: the system reads it, the demo only steps over it and its value.
                if arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("-") {
                    index += 1
                }
            }
            index += 1
        }
        return result
    }

    /// The command line the demo accepts.
    static let usage = """
        Usage: SidebarSettingsDemo [--icons plain|tiled] [--appearance light|dark] \
        [--scenario 1|2|3|4|5|6|6b|7] [--window-id-file PATH]
        """

    /// Writes `message` and the usage to stderr, then exits with `code`.
    static func exitWithUsage(_ message: String, code: Int32 = 2) -> Never {
        writeToStandardError("\(message)\n\n\(usage)\n")
        Darwin.exit(code)
    }

    /// Writes `message` to stderr, then exits with `code`.
    static func exit(_ message: String, code: Int32 = 1) -> Never {
        writeToStandardError("\(message)\n")
        Darwin.exit(code)
    }

    private static func writeToStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }

    /// The argument after the option at `index`, moving `index` onto it.
    private static func value(
        of option: String,
        in arguments: [String],
        at index: inout Int
    ) throws -> String {
        guard arguments.indices.contains(index + 1) else {
            throw ParseError.missingValue(option: option)
        }
        index += 1
        return arguments[index]
    }
}

extension DemoArguments.ParseError: CustomStringConvertible {
    var description: String {
        switch self {
        case .unknownOption(let option):
            return "Unknown option \(option)."
        case .missingValue(let option):
            return "\(option) needs a value."
        case .unknownValue(let option, let value):
            return "\(option) does not take \(value)."
        }
    }
}

extension DemoArguments.Icons: DemoChoice {
    /// The control panel's row of text for this choice.
    var label: String { rawValue.capitalized }

    /// The kit's choice this name stands for.
    var value: SidebarSettingsConfiguration.Icons {
        switch self {
        case .plain: .plain
        case .tiled: .tiled
        }
    }
}

extension DemoArguments.Appearance {
    /// The `NSAppearance` this name stands for.
    var nsAppearance: NSAppearance {
        let name: NSAppearance.Name = self == .light ? .aqua : .darkAqua
        guard let appearance = NSAppearance(named: name) else {
            DemoArguments.exit("The \(rawValue) appearance is not available on this system.")
        }
        return appearance
    }
}
