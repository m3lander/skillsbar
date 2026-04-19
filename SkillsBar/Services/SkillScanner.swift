import Foundation

struct SkillScanner {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    func scanAll() -> [Skill] {
        var skills: [Skill] = []
        skills.append(contentsOf: scanClaudeCodeUserSkills())
        skills.append(contentsOf: scanClaudeCodePluginSkills())
        skills.append(contentsOf: scanCodexPluginSkills())
        skills.append(contentsOf: scanCodexBuiltInSkills())
        skills.append(contentsOf: scanCodexUserSkills())
        skills.append(contentsOf: scanPiCLISkills())
        return skills
    }

    // MARK: - Claude Code

    /// Scans ~/.claude/skills/ for direct child folders containing SKILL.md
    func scanClaudeCodeUserSkills() -> [Skill] {
        let dir = (home as NSString).appendingPathComponent(".claude/skills")
        return scanDirectChildren(dir: dir, source: .claudeCode(.user))
    }

    /// Recursively scans ~/.claude/plugins/cache/ for any SKILL.md files
    func scanClaudeCodePluginSkills() -> [Skill] {
        let dir = (home as NSString).appendingPathComponent(".claude/plugins/cache")
        guard fileManager.fileExists(atPath: dir) else { return [] }

        var skills: [Skill] = []
        guard let enumerator = fileManager.enumerator(atPath: dir) else { return [] }

        while let relativePath = enumerator.nextObject() as? String {
            guard (relativePath as NSString).lastPathComponent == "SKILL.md" else { continue }
            let fullPath = (dir as NSString).appendingPathComponent(relativePath)
            if let skill = parseSkillMD(at: fullPath, source: .claudeCode(.plugin)) {
                skills.append(skill)
            }
        }

        return skills
    }

    // MARK: - Codex CLI

    /// Scans ~/.codex/skills/.system/ for built-in skills
    func scanCodexBuiltInSkills() -> [Skill] {
        let dir = (home as NSString).appendingPathComponent(".codex/skills/.system")
        return scanDirectChildren(dir: dir, source: .codexCLI(.builtin), checkAgentYaml: true)
    }

    /// Recursively scans ~/.codex/plugins/cache/ for files matching */skills/*/SKILL.md
    func scanCodexPluginSkills() -> [Skill] {
        let dir = (home as NSString).appendingPathComponent(".codex/plugins/cache")
        guard fileManager.fileExists(atPath: dir) else { return [] }
        guard let enumerator = fileManager.enumerator(atPath: dir) else { return [] }

        var skillsByIdentifier: [String: Skill] = [:]

        while let relativePath = enumerator.nextObject() as? String {
            guard (relativePath as NSString).lastPathComponent == "SKILL.md" else { continue }

            let parentDir = (relativePath as NSString).deletingLastPathComponent
            let skillsDir = (parentDir as NSString).deletingLastPathComponent
            guard (skillsDir as NSString).lastPathComponent == "skills" else { continue }

            let fullPath = (dir as NSString).appendingPathComponent(relativePath)
            let fullParentDir = (dir as NSString).appendingPathComponent(parentDir)

            if let skill = parseSkillMD(at: fullPath, source: .codexCLI(.plugin), checkAgentYaml: true, parentDir: fullParentDir) {
                let key = skill.triggerCommand.lowercased()
                if let existing = skillsByIdentifier[key] {
                    let newDate = skill.lastModified ?? .distantPast
                    let existingDate = existing.lastModified ?? .distantPast
                    if newDate >= existingDate {
                        skillsByIdentifier[key] = skill
                    }
                } else {
                    skillsByIdentifier[key] = skill
                }
            }
        }

        return Array(skillsByIdentifier.values)
    }

    /// Scans ~/.codex/skills/ for user-installed skills (excluding .system)
    func scanCodexUserSkills() -> [Skill] {
        let dir = (home as NSString).appendingPathComponent(".codex/skills")
        guard fileManager.fileExists(atPath: dir) else { return [] }

        var skills: [Skill] = []
        guard let children = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }

        for child in children where child != ".system" && !child.hasPrefix(".") {
            let childPath = (dir as NSString).appendingPathComponent(child)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let skillPath = (childPath as NSString).appendingPathComponent("SKILL.md")
            if let skill = parseSkillMD(at: skillPath, source: .codexCLI(.user), checkAgentYaml: true, parentDir: childPath) {
                skills.append(skill)
            }
        }

        return skills
    }

    // MARK: - Pi CLI

    /// Scans Pi CLI's fixed built-in discovery roots.
    func scanPiCLISkills() -> [Skill] {
        let managedPath = Self.piManagedSkillsPath(fileManager: fileManager)
        let sharedPath = Self.piSharedSkillsPath(fileManager: fileManager)
        let roots = Self.piBuiltInDiscoveryRoots(fileManager: fileManager)

        var discovered: [Skill] = []
        var seenPaths: Set<String> = []

        for root in roots {
            let source: SkillSource
            if root == managedPath {
                source = .piCLI(.managed)
            } else if root == sharedPath {
                source = .piCLI(.shared)
            } else {
                source = .piCLI(.workspace)
            }

            for skill in scanDirectChildren(dir: root, source: source) {
                let standardizedPath = (skill.path as NSString).standardizingPath
                guard seenPaths.insert(standardizedPath).inserted else { continue }
                discovered.append(skill)
            }
        }

        return discovered
    }

    static func piBuiltInDiscoveryRoots(fileManager: FileManager = .default) -> [String] {
        let managedPath = piManagedSkillsPath(fileManager: fileManager)
        let sharedPath = piSharedSkillsPath(fileManager: fileManager)
        let currentDirectory = (fileManager.currentDirectoryPath as NSString).standardizingPath

        var roots: [String] = [
            managedPath,
            sharedPath,
            (currentDirectory as NSString).appendingPathComponent(".pi/skills")
        ]

        for directory in ancestorDirectoriesForPiDiscovery(startingAt: currentDirectory, fileManager: fileManager) {
            roots.append((directory as NSString).appendingPathComponent(".agents/skills"))
        }

        return dedupePaths(roots)
    }

    // MARK: - Helpers

    private func scanDirectChildren(dir: String, source: SkillSource, checkAgentYaml: Bool = false) -> [Skill] {
        guard fileManager.fileExists(atPath: dir) else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }

        var skills: [Skill] = []
        for child in children where !child.hasPrefix(".") {
            let childPath = (dir as NSString).appendingPathComponent(child)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let skillPath = (childPath as NSString).appendingPathComponent("SKILL.md")
            if let skill = parseSkillMD(at: skillPath, source: source, checkAgentYaml: checkAgentYaml, parentDir: childPath) {
                skills.append(skill)
            }
        }
        return skills
    }

    private func parseSkillMD(at path: String, source: SkillSource, checkAgentYaml: Bool = false, parentDir: String? = nil) -> Skill? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        guard let parsed = FrontmatterParser.parse(content: content) else {
            // If no valid frontmatter, still create a skill with folder name
            let folderName = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
            return Skill(name: folderName, description: "", source: source, path: path)
        }

        var name = parsed.name
        var description = parsed.description

        // For Codex skills, check agents/openai.yaml for better display info
        if checkAgentYaml, let dir = parentDir {
            let agentPath = (dir as NSString).appendingPathComponent("agents/openai.yaml")
            if let agentContent = try? String(contentsOfFile: agentPath, encoding: .utf8) {
                let agent = FrontmatterParser.parseOpenAIAgent(content: agentContent)
                if let displayName = agent.displayName, !displayName.isEmpty {
                    name = displayName
                }
                if let shortDesc = agent.shortDescription, !shortDesc.isEmpty, description.isEmpty {
                    description = shortDesc
                }
            }
        }

        // Fallback name to folder name
        if name.isEmpty {
            name = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
        }

        // File metadata
        let skillDir = (path as NSString).deletingLastPathComponent
        let lastModified = (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        let allItems = (try? fileManager.contentsOfDirectory(atPath: skillDir))?
            .filter { !$0.hasPrefix(".") }
            .sorted() ?? []
        var directories: Set<String> = []
        var dirContents: [String: [String]] = [:]
        for item in allItems {
            var isDir: ObjCBool = false
            let itemPath = (skillDir as NSString).appendingPathComponent(item)
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                directories.insert(item)
                dirContents[item] = (try? fileManager.contentsOfDirectory(atPath: itemPath))?
                    .filter { !$0.hasPrefix(".") }
                    .sorted() ?? []
            }
        }

        return Skill(name: name, description: description, source: source, path: path, version: parsed.version, body: parsed.body, lastModified: lastModified, folderContents: allItems, folderDirectories: directories, directoryContents: dirContents)
    }

    private static func piManagedSkillsPath(fileManager: FileManager) -> String {
        let env = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = fileManager.homeDirectoryForCurrentUser.path
        let baseDir = (env?.isEmpty == false ? env! : "\(home)/.pi/agent")
        let expandedBaseDir = (baseDir as NSString).expandingTildeInPath
        return ((expandedBaseDir as NSString).appendingPathComponent("skills") as NSString).standardizingPath
    }

    private static func piSharedSkillsPath(fileManager: FileManager) -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return ("\(home)/.agents/skills" as NSString).standardizingPath
    }

    private static func ancestorDirectoriesForPiDiscovery(startingAt startPath: String, fileManager: FileManager) -> [String] {
        var directories: [String] = []
        var currentPath = (startPath as NSString).standardizingPath
        let stopPath = piAncestorWalkStopPath(startingAt: currentPath, fileManager: fileManager)

        while true {
            directories.append(currentPath)
            if currentPath == stopPath || currentPath == "/" {
                break
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
            if currentPath.isEmpty {
                currentPath = "/"
            }
        }

        return directories
    }

    private static func piAncestorWalkStopPath(startingAt startPath: String, fileManager: FileManager) -> String {
        var currentPath = (startPath as NSString).standardizingPath
        while true {
            let gitEntry = (currentPath as NSString).appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitEntry) {
                return currentPath
            }

            if currentPath == "/" {
                return "/"
            }

            let parent = (currentPath as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == currentPath {
                return "/"
            }
            currentPath = parent
        }
    }

    private static func dedupePaths(_ paths: [String]) -> [String] {
        var seen: Set<String> = []
        var deduped: [String] = []

        for path in paths.map({ ($0 as NSString).standardizingPath }) where seen.insert(path).inserted {
            deduped.append(path)
        }

        return deduped
    }
}
