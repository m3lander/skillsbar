import Foundation

enum SkillSource: Hashable {
    case claudeCode(ClaudeCodeSection)
    case codexCLI(CodexSection)
    case hermes(HermesSection)
    case openClaw(OpenClawSection)
    case pi(PiSection)

    enum ClaudeCodeSection: String, Hashable {
        case user = "User Skills"
        case plugin = "Plugin Skills"
    }

    enum CodexSection: String, Hashable {
        case builtin = "Built-in Skills"
        case plugin = "Plugin Skills"
        case user = "User Skills"
    }

    enum HermesSection: String, Hashable {
        case profileLocal = "Profile Skills"
        case external = "External Directories"
        case plugin = "Plugin Skills"
        case optional = "Official Optional Skills"
    }

    enum OpenClawSection: String, Hashable {
        case workspace = "Workspace Skills"
        case projectAgents = "Project .agents Skills"
        case personalAgents = "Personal .agents Skills"
        case managed = "Managed Skills"
        case bundled = "Bundled Skills"
        case extra = "Extra Directories"
        case plugin = "Plugin Skills"
    }

    enum PiSection: String, Hashable {
        case agentHome = "Pi Agent Skills"
        case personalAgents = "Personal .agents Skills"
        case settings = "Settings Skills"
        case package = "Package Skills"
    }

    var groupID: String {
        switch self {
        case .claudeCode: return "claude-code"
        case .codexCLI: return "codex-cli"
        case .hermes: return "hermes"
        case .openClaw: return "openclaw"
        case .pi: return "pi"
        }
    }

    var groupTitle: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codexCLI: return "Codex CLI"
        case .hermes: return "Hermes"
        case .openClaw: return "OpenClaw"
        case .pi: return "Pi"
        }
    }

    var shortLabel: String {
        switch self {
        case .claudeCode: return "Claude"
        case .codexCLI: return "Codex"
        case .hermes: return "Hermes"
        case .openClaw: return "OpenClaw"
        case .pi: return "Pi"
        }
    }

    var sectionTitle: String {
        switch self {
        case .claudeCode(let section): return section.rawValue
        case .codexCLI(let section): return section.rawValue
        case .hermes(let section): return section.rawValue
        case .openClaw(let section): return section.rawValue
        case .pi(let section): return section.rawValue
        }
    }

    var sectionID: String {
        switch self {
        case .claudeCode(let section):
            switch section {
            case .user: return "claude-user"
            case .plugin: return "claude-plugin"
            }
        case .codexCLI(let section):
            switch section {
            case .user: return "codex-user"
            case .plugin: return "codex-plugin"
            case .builtin: return "codex-builtin"
            }
        case .hermes(let section):
            switch section {
            case .profileLocal: return "hermes-profile-local"
            case .external: return "hermes-external"
            case .plugin: return "hermes-plugin"
            case .optional: return "hermes-optional"
            }
        case .openClaw(let section):
            switch section {
            case .workspace: return "openclaw-workspace"
            case .projectAgents: return "openclaw-project-agents"
            case .personalAgents: return "openclaw-personal-agents"
            case .managed: return "openclaw-managed"
            case .bundled: return "openclaw-bundled"
            case .extra: return "openclaw-extra"
            case .plugin: return "openclaw-plugin"
            }
        case .pi(let section):
            switch section {
            case .agentHome: return "pi-agent-home"
            case .personalAgents: return "pi-personal-agents"
            case .settings: return "pi-settings"
            case .package: return "pi-package"
            }
        }
    }

    var iconName: String {
        switch self {
        case .claudeCode: return "ClaudeLogo"
        case .codexCLI: return "OpenAILogo"
        case .hermes: return "sparkles"
        case .openClaw: return "terminal"
        case .pi: return "hexagon"
        }
    }

    var isCustomIcon: Bool {
        switch self {
        case .claudeCode, .codexCLI: return true
        case .hermes, .openClaw, .pi: return false
        }
    }

    var badgeColor: String {
        switch self {
        case .claudeCode(.user): return "orange"
        case .claudeCode(.plugin): return "orange"
        case .codexCLI(.builtin): return "purple"
        case .codexCLI(.plugin): return "purple"
        case .codexCLI(.user): return "purple"
        case .hermes(.profileLocal): return "blue"
        case .hermes(.external): return "teal"
        case .hermes(.plugin): return "blue"
        case .hermes(.optional): return "gray"
        case .openClaw(.workspace): return "green"
        case .openClaw(.projectAgents): return "green"
        case .openClaw(.personalAgents): return "green"
        case .openClaw(.managed): return "green"
        case .openClaw(.bundled): return "gray"
        case .openClaw(.extra): return "teal"
        case .openClaw(.plugin): return "gray"
        case .pi(.agentHome): return "pink"
        case .pi(.personalAgents): return "pink"
        case .pi(.settings): return "teal"
        case .pi(.package): return "gray"
        }
    }

    var isReadOnly: Bool {
        switch self {
        case .claudeCode(.plugin), .codexCLI(.builtin), .codexCLI(.plugin):
            return true
        case .hermes(.external), .hermes(.plugin), .hermes(.optional):
            return true
        case .openClaw(.bundled), .openClaw(.extra), .openClaw(.plugin):
            return true
        case .pi(.settings), .pi(.package):
            return true
        case .claudeCode(.user), .codexCLI(.user), .hermes(.profileLocal),
             .openClaw(.workspace), .openClaw(.projectAgents), .openClaw(.personalAgents),
             .openClaw(.managed), .pi(.agentHome), .pi(.personalAgents):
            return false
        }
    }

    var isDeletable: Bool { !isReadOnly }
}
