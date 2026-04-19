import Foundation

enum SkillSource: Hashable {
    case claudeCode(ClaudeCodeSection)
    case codexCLI(CodexSection)
    case piCLI(PiSection)

    enum ClaudeCodeSection: String, Hashable {
        case user = "User Skills"
        case plugin = "Plugin Skills"
    }

    enum CodexSection: String, Hashable {
        case builtin = "Built-in Skills"
        case plugin = "Plugin Skills"
        case user = "User Skills"
    }

    enum PiSection: String, Hashable {
        case managed = "Agent Skills"
        case shared = "Shared Skills"
        case workspace = "Workspace Skills"
    }

    var groupTitle: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codexCLI: return "Codex CLI"
        case .piCLI: return "Pi CLI"
        }
    }

    var sectionTitle: String {
        switch self {
        case .claudeCode(let section): return section.rawValue
        case .codexCLI(let section): return section.rawValue
        case .piCLI(let section): return section.rawValue
        }
    }

    var iconName: String {
        switch self {
        case .claudeCode: return "ClaudeLogo"
        case .codexCLI: return "OpenAILogo"
        case .piCLI: return "OpenAILogo"
        }
    }

    var isCustomIcon: Bool { true }

    var badgeColor: String {
        switch self {
        case .claudeCode(.user): return "orange"
        case .claudeCode(.plugin): return "orange"
        case .codexCLI(.builtin): return "purple"
        case .codexCLI(.plugin): return "purple"
        case .codexCLI(.user): return "purple"
        case .piCLI(.managed): return "indigo"
        case .piCLI(.shared): return "indigo"
        case .piCLI(.workspace): return "indigo"
        }
    }

    var shortLabel: String {
        switch self {
        case .claudeCode:
            return "Claude"
        case .codexCLI:
            return "Codex"
        case .piCLI:
            return "Pi"
        }
    }
}
