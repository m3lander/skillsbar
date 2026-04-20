import Foundation

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let source: SkillSource
    let path: String
    var version: String?
    var body: String = ""
    var lastModified: Date?
    var folderContents: [String] = []
    var folderDirectories: Set<String> = []
    var directoryContents: [String: [String]] = [:]

    init(name: String, description: String, source: SkillSource, path: String, version: String? = nil, body: String = "", lastModified: Date? = nil, folderContents: [String] = [], folderDirectories: Set<String> = [], directoryContents: [String: [String]] = [:]) {
        self.id = "\(source.sectionID)::\((path as NSString).standardizingPath)"
        self.name = name
        self.description = description
        self.source = source
        self.path = (path as NSString).standardizingPath
        self.version = version
        self.body = body
        self.lastModified = lastModified
        self.folderContents = folderContents
        self.folderDirectories = folderDirectories
        self.directoryContents = directoryContents
    }

    var displayName: String {
        name.isEmpty ? URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent : name
    }

    var shortDescription: String {
        let firstLine = description.components(separatedBy: .newlines).first ?? description
        if firstLine.count > 120 {
            return String(firstLine.prefix(117)) + "..."
        }
        return firstLine
    }

    var isNew: Bool {
        guard let date = lastModified else { return false }
        return Date().timeIntervalSince(date) < 86400
    }

    var formattedLastModified: String? {
        guard let date = lastModified else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var triggerCommand: String {
        let skillName: String = {
            let url = URL(fileURLWithPath: path)
            if url.lastPathComponent.lowercased().hasSuffix(".md"),
               url.lastPathComponent != "SKILL.md" {
                return url.deletingPathExtension().lastPathComponent
            }
            return url.deletingLastPathComponent().lastPathComponent
        }()

        switch source {
        case .claudeCode(.user):
            // ~/.claude/skills/<folder-name>/SKILL.md -> /folder-name
            return "/\(skillName)"

        case .claudeCode(.plugin):
            // ~/.claude/plugins/cache/<repo>/<plugin>/<ver>/skills/<skill>/SKILL.md
            // trigger: plugin-name:skill-name
            let components = path.components(separatedBy: "/")
            if let skillsIdx = components.lastIndex(of: "skills"),
               skillsIdx > 1,
               skillsIdx + 1 < components.count {
                let pluginName = components[skillsIdx - 2]
                let skillName = components[skillsIdx + 1]
                return "\(pluginName):\(skillName)"
            }
            return skillName

        case .codexCLI(.builtin):
            return skillName

        case .codexCLI(.plugin):
            let components = path.components(separatedBy: "/")
            if let skillsIdx = components.lastIndex(of: "skills"),
               skillsIdx > 1,
               skillsIdx + 1 < components.count {
                let pluginName = components[skillsIdx - 2]
                let skillName = components[skillsIdx + 1]
                return "\(pluginName):\(skillName)"
            }
            return skillName

        case .codexCLI(.user):
            return skillName

        case .hermes(.plugin):
            let components = path.components(separatedBy: "/")
            if let skillsIdx = components.lastIndex(of: "skills"),
               skillsIdx > 0,
               skillsIdx + 1 < components.count {
                let pluginName = components[skillsIdx - 1]
                let skillName = components[skillsIdx + 1]
                return "\(pluginName):\(skillName)"
            }
            return skillName

        case .hermes:
            return skillName

        case .openClaw:
            return "/\(skillName)"

        case .pi:
            return "/skill:\(skillName)"
        }
    }

    var triggerHint: String {
        switch source {
        case .claudeCode(.user):
            return "Type in Claude Code CLI"
        case .claudeCode(.plugin):
            return "Use the Skill tool or type /skill-name in Claude Code"
        case .codexCLI(.builtin):
            return "Available by default in Codex CLI"
        case .codexCLI(.plugin):
            return "Available through an installed Codex plugin"
        case .codexCLI(.user):
            return "Available as an installed skill in Codex CLI"
        case .hermes(.profileLocal):
            return "Available in the owning Hermes profile"
        case .hermes(.external):
            return "Loaded from Hermes skills.external_dirs"
        case .hermes(.plugin):
            return "Load explicitly with skill_view(\"plugin:skill\") in Hermes"
        case .hermes(.optional):
            return "Official Hermes optional skill; install or copy into a profile to edit"
        case .openClaw(.workspace):
            return "Highest-precedence OpenClaw workspace skill"
        case .openClaw(.projectAgents):
            return "OpenClaw project .agents skill for configured workspaces"
        case .openClaw(.personalAgents):
            return "OpenClaw personal .agents skill"
        case .openClaw(.managed):
            return "Managed OpenClaw skill available to all local agents"
        case .openClaw(.bundled):
            return "Bundled OpenClaw skill"
        case .openClaw(.extra):
            return "Loaded from OpenClaw skills.load.extraDirs"
        case .openClaw(.plugin):
            return "Loaded from an enabled OpenClaw plugin skill directory"
        case .pi(.agentHome):
            return "Available from the Pi coding agent skills directory"
        case .pi(.personalAgents):
            return "Available from ~/.agents/skills for Pi"
        case .pi(.settings):
            return "Loaded from Pi settings skills[]"
        case .pi(.package):
            return "Loaded from an installed package pi.skills manifest"
        }
    }
}
