import Foundation

struct SkillDirectoryTarget: Hashable {
    let displayPath: String
    let path: String
}

struct SkillScanner {
    private let fileManager: FileManager
    private let home: String
    private let environment: [String: String]

    init(
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.home = (home as NSString).standardizingPath
        self.environment = environment
        self.fileManager = fileManager
    }

    func scanAll() -> [Skill] {
        var skills: [Skill] = []
        skills.append(contentsOf: scanClaudeCodeUserSkills())
        skills.append(contentsOf: scanClaudeCodePluginSkills())
        skills.append(contentsOf: scanCodexPluginSkills())
        skills.append(contentsOf: scanCodexBuiltInSkills())
        skills.append(contentsOf: scanCodexUserSkills())
        skills.append(contentsOf: scanHermesSkills())
        skills.append(contentsOf: scanOpenClawSkills())
        skills.append(contentsOf: scanPiSkills())
        return skills
    }

    func watchedDirectories() -> [SkillDirectoryTarget] {
        SkillScanner.watchedDirectories(home: home, environment: environment)
    }

    static func watchedDirectories(
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [SkillDirectoryTarget] {
        SkillScanner(home: home, environment: environment).resolvedWatchDirectories()
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
        return scanRecursiveSkillMD(dir: dir, source: .claudeCode(.plugin))
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
            if shouldSkip(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }
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

        for child in children where child != ".system" && !shouldSkipComponent(child) {
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

    // MARK: - Hermes

    func scanHermesSkills() -> [Skill] {
        var skills: [Skill] = []
        for profileDir in hermesProfileDirectories() {
            skills.append(contentsOf: scanRootOrSkill(dir: (profileDir as NSString).appendingPathComponent("skills"), source: .hermes(.profileLocal), includeLegacyFlatMarkdown: true))
            for externalDir in hermesExternalDirs(profileDir: profileDir) {
                skills.append(contentsOf: scanRootOrSkill(dir: externalDir, source: .hermes(.external), includeLegacyFlatMarkdown: true))
            }
            for pluginSkillsDir in hermesPluginSkillDirs(profileDir: profileDir) {
                skills.append(contentsOf: scanRootOrSkill(dir: pluginSkillsDir, source: .hermes(.plugin), includeLegacyFlatMarkdown: false))
            }
        }

        if let optionalDir = hermesOptionalSkillsDir() {
            skills.append(contentsOf: scanRootOrSkill(dir: optionalDir, source: .hermes(.optional), includeLegacyFlatMarkdown: false))
        }

        return dedupeSkills(skills)
    }

    private func hermesProfileDirectories() -> [String] {
        var dirs = [(home as NSString).appendingPathComponent(".hermes")]
        let profilesRoot = (home as NSString).appendingPathComponent(".hermes/profiles")
        if let children = try? fileManager.contentsOfDirectory(atPath: profilesRoot) {
            for child in children where !shouldSkipComponent(child) {
                let childPath = (profilesRoot as NSString).appendingPathComponent(child)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue {
                    dirs.append(childPath)
                }
            }
        }
        return dedupePaths(dirs)
    }

    private func hermesExternalDirs(profileDir: String) -> [String] {
        let configPath = (profileDir as NSString).appendingPathComponent("config.yaml")
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
        return parseYAMLStringList(content: content, path: ["skills", "external_dirs"])
            .map { resolvePath($0) }
    }

    private func hermesPluginSkillDirs(profileDir: String) -> [String] {
        let pluginsRoot = (profileDir as NSString).appendingPathComponent("plugins")
        guard let children = try? fileManager.contentsOfDirectory(atPath: pluginsRoot) else { return [] }

        return children.compactMap { child in
            guard !shouldSkipComponent(child) else { return nil }
            let skillDir = ((pluginsRoot as NSString).appendingPathComponent(child) as NSString).appendingPathComponent("skills")
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: skillDir, isDirectory: &isDir) && isDir.boolValue ? skillDir : nil
        }
    }

    private func hermesOptionalSkillsDir() -> String? {
        if let configured = environment["HERMES_OPTIONAL_SKILLS"], !configured.isEmpty {
            return resolvePath(configured)
        }
        return (home as NSString).appendingPathComponent(".hermes/hermes-agent/optional-skills")
    }

    // MARK: - OpenClaw

    func scanOpenClawSkills() -> [Skill] {
        let config = openClawConfig()
        var skills: [Skill] = []

        for workspace in config.workspaces {
            skills.append(contentsOf: scanRootOrSkill(dir: (workspace as NSString).appendingPathComponent("skills"), source: .openClaw(.workspace)))
            skills.append(contentsOf: scanRootOrSkill(dir: (workspace as NSString).appendingPathComponent(".agents/skills"), source: .openClaw(.projectAgents)))
        }

        skills.append(contentsOf: scanRootOrSkill(dir: (home as NSString).appendingPathComponent(".agents/skills"), source: .openClaw(.personalAgents)))
        skills.append(contentsOf: scanRootOrSkill(dir: (config.stateDir as NSString).appendingPathComponent("skills"), source: .openClaw(.managed)))

        if let bundled = config.bundledSkillsDir {
            skills.append(contentsOf: scanRootOrSkill(dir: bundled, source: .openClaw(.bundled)))
        }

        for extraDir in config.extraDirs {
            skills.append(contentsOf: scanRootOrSkill(dir: extraDir, source: .openClaw(.extra)))
        }

        for pluginSkillsDir in config.pluginSkillDirs {
            skills.append(contentsOf: scanRootOrSkill(dir: pluginSkillsDir, source: .openClaw(.plugin)))
        }

        return dedupeSkills(skills)
    }

    private func openClawConfig() -> OpenClawResolvedConfig {
        let stateDir = resolvePath(environment["OPENCLAW_STATE_DIR"] ?? "~/.openclaw")
        let configPath = resolvePath(environment["OPENCLAW_CONFIG_PATH"] ?? "\(stateDir)/openclaw.json")
        let bundledSkillsDir = openClawBundledSkillsDir()

        var config = OpenClawResolvedConfig(
            stateDir: stateDir,
            workspaces: [],
            extraDirs: [],
            pluginSkillDirs: [],
            bundledSkillsDir: bundledSkillsDir
        )

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return config
        }

        config.workspaces = extractStringArray(from: object, paths: [
            ["workspaces"],
            ["workspaceDirs"],
            ["agents", "workspaces"],
            ["agents", "workspaceDirs"],
            ["agents", "list", "workspace"],
            ["agents", "list", "cwd"],
        ]).map { resolvePath($0) }

        config.extraDirs = extractStringArray(from: object, paths: [
            ["skills", "load", "extraDirs"],
            ["skills", "extraDirs"],
            ["skillDirs"],
        ]).map { resolvePath($0) }

        let pluginRoots = extractStringArray(from: object, paths: [
            ["plugins", "dirs"],
            ["plugins", "roots"],
            ["pluginDirs"],
        ]).map { resolvePath($0) }

        config.pluginSkillDirs = pluginSkillDirs(pluginRoots: pluginRoots)
        return config
    }

    private func openClawBundledSkillsDir() -> String? {
        if let configured = environment["OPENCLAW_BUNDLED_SKILLS_DIR"], !configured.isEmpty {
            return resolvePath(configured)
        }

        return resolvePath("~/.bun/install/global/node_modules/openclaw/skills")
    }

    private func pluginSkillDirs(pluginRoots: [String]) -> [String] {
        var dirs: [String] = []
        for pluginRoot in pluginRoots {
            dirs.append(contentsOf: pluginSkillDirsFromManifest(pluginDir: pluginRoot))
            guard let children = try? fileManager.contentsOfDirectory(atPath: pluginRoot) else { continue }
            for child in children where !shouldSkipComponent(child) {
                let pluginDir = (pluginRoot as NSString).appendingPathComponent(child)
                dirs.append(contentsOf: pluginSkillDirsFromManifest(pluginDir: pluginDir))
            }
        }
        return dedupePaths(dirs)
    }

    private func pluginSkillDirsFromManifest(pluginDir: String) -> [String] {
        let manifestPath = (pluginDir as NSString).appendingPathComponent("openclaw.plugin.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        return stringArrayValue(manifest["skills"]).map { resolvePath($0, relativeTo: pluginDir) }
    }

    // MARK: - Pi

    func scanPiSkills() -> [Skill] {
        let piHome = resolvePath(environment["PI_CODING_AGENT_DIR"] ?? "~/.pi/agent")
        var skills: [Skill] = []

        skills.append(contentsOf: scanRootOrSkill(dir: (piHome as NSString).appendingPathComponent("skills"), source: .pi(.agentHome), includeLegacyFlatMarkdown: true))
        skills.append(contentsOf: scanRootOrSkill(dir: (home as NSString).appendingPathComponent(".agents/skills"), source: .pi(.personalAgents), includeLegacyFlatMarkdown: false))

        for settingsPath in piSettingsPaths(piHome: piHome) {
            for configured in piConfiguredSkillPaths(settingsPath: settingsPath) {
                skills.append(contentsOf: scanRootOrSkill(dir: configured, source: .pi(.settings), includeLegacyFlatMarkdown: true))
            }
        }

        for packageSkillDir in piPackageSkillDirs(piHome: piHome) {
            skills.append(contentsOf: scanRootOrSkill(dir: packageSkillDir, source: .pi(.package), includeLegacyFlatMarkdown: true))
        }

        return dedupeSkills(skills)
    }

    private func piSettingsPaths(piHome: String) -> [String] {
        dedupePaths([
            (piHome as NSString).appendingPathComponent("settings.json"),
            (home as NSString).appendingPathComponent(".pi/agent/settings.json"),
        ])
    }

    private func piConfiguredSkillPaths(settingsPath: String) -> [String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let base = (settingsPath as NSString).deletingLastPathComponent
        return stringArrayValue(object["skills"]).map { resolvePath($0, relativeTo: base) }
    }

    private func piPackageSkillDirs(piHome: String) -> [String] {
        let nodeModules = (home as NSString).appendingPathComponent(".pi/agent/node_modules")
        var dirs: [String] = []
        dirs.append(contentsOf: scanPackageManifests(root: nodeModules))
        if piHome != (home as NSString).appendingPathComponent(".pi/agent") {
            dirs.append(contentsOf: scanPackageManifests(root: (piHome as NSString).appendingPathComponent("node_modules")))
        }
        return dedupePaths(dirs)
    }

    private func scanPackageManifests(root: String) -> [String] {
        guard fileManager.fileExists(atPath: root),
              let enumerator = fileManager.enumerator(atPath: root) else { return [] }
        var dirs: [String] = []

        while let relativePath = enumerator.nextObject() as? String {
            if shouldSkip(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }
            guard (relativePath as NSString).lastPathComponent == "package.json" else { continue }
            let manifestPath = (root as NSString).appendingPathComponent(relativePath)
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let packageDir = (manifestPath as NSString).deletingLastPathComponent
            dirs.append(contentsOf: extractStringArray(from: object, paths: [
                ["pi", "skills"],
                ["pi.skills"],
            ]).map { resolvePath($0, relativeTo: packageDir) })

            let conventional = (packageDir as NSString).appendingPathComponent("skills")
            if fileManager.fileExists(atPath: conventional) {
                dirs.append(conventional)
            }
        }

        return dirs
    }

    // MARK: - Shared Scanning Helpers

    private func scanDirectChildren(dir: String, source: SkillSource, checkAgentYaml: Bool = false) -> [Skill] {
        guard fileManager.fileExists(atPath: dir) else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }

        var skills: [Skill] = []
        for child in children where !shouldSkipComponent(child) {
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

    private func scanRootOrSkill(dir: String, source: SkillSource, includeLegacyFlatMarkdown: Bool = false) -> [Skill] {
        let resolved = (dir as NSString).standardizingPath
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: resolved, isDirectory: &isDir) else { return [] }

        if !isDir.boolValue {
            guard resolved.lowercased().hasSuffix(".md") else { return [] }
            return parseSkillMD(at: resolved, source: source).map { [$0] } ?? []
        }

        let directSkill = (resolved as NSString).appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: directSkill) {
            return parseSkillMD(at: directSkill, source: source, parentDir: resolved).map { [$0] } ?? []
        }

        var skills = scanRecursiveSkillMD(dir: resolved, source: source)
        if includeLegacyFlatMarkdown {
            skills.append(contentsOf: scanLegacyFlatMarkdown(dir: resolved, source: source))
        }
        return skills
    }

    private func scanRecursiveSkillMD(dir: String, source: SkillSource, checkAgentYaml: Bool = false) -> [Skill] {
        guard fileManager.fileExists(atPath: dir) else { return [] }
        guard let enumerator = fileManager.enumerator(atPath: dir) else { return [] }

        var skills: [Skill] = []
        while let relativePath = enumerator.nextObject() as? String {
            if shouldSkip(relativePath: relativePath) {
                enumerator.skipDescendants()
                continue
            }
            guard (relativePath as NSString).lastPathComponent == "SKILL.md" else { continue }
            let fullPath = (dir as NSString).appendingPathComponent(relativePath)
            let parentDir = (fullPath as NSString).deletingLastPathComponent
            if let skill = parseSkillMD(at: fullPath, source: source, checkAgentYaml: checkAgentYaml, parentDir: parentDir) {
                skills.append(skill)
            }
        }
        return skills
    }

    private func scanLegacyFlatMarkdown(dir: String, source: SkillSource) -> [Skill] {
        guard let children = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }
        return children.compactMap { child in
            guard !shouldSkipComponent(child),
                  child.lowercased().hasSuffix(".md"),
                  child != "SKILL.md" else { return nil }
            return parseSkillMD(at: (dir as NSString).appendingPathComponent(child), source: source)
        }
    }

    private func parseSkillMD(at path: String, source: SkillSource, checkAgentYaml: Bool = false, parentDir: String? = nil) -> Skill? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let pathURL = URL(fileURLWithPath: path)
        let fallbackName = pathURL.lastPathComponent == "SKILL.md"
            ? pathURL.deletingLastPathComponent().lastPathComponent
            : pathURL.deletingPathExtension().lastPathComponent

        guard let parsed = FrontmatterParser.parse(content: content) else {
            return Skill(name: fallbackName, description: "", source: source, path: path)
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

        if name.isEmpty {
            name = fallbackName
        }

        let skillDir = (path as NSString).deletingLastPathComponent
        let lastModified = (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        let allItems = (try? fileManager.contentsOfDirectory(atPath: skillDir))?
            .filter { !shouldSkipComponent($0) }
            .sorted() ?? []
        var directories: Set<String> = []
        var dirContents: [String: [String]] = [:]
        for item in allItems {
            var isDir: ObjCBool = false
            let itemPath = (skillDir as NSString).appendingPathComponent(item)
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                directories.insert(item)
                dirContents[item] = (try? fileManager.contentsOfDirectory(atPath: itemPath))?
                    .filter { !shouldSkipComponent($0) }
                    .sorted() ?? []
            }
        }

        return Skill(name: name, description: description, source: source, path: path, version: parsed.version, body: parsed.body, lastModified: lastModified, folderContents: allItems, folderDirectories: directories, directoryContents: dirContents)
    }

    // MARK: - Shared Path Resolver

    private func resolvedWatchDirectories() -> [SkillDirectoryTarget] {
        var targets: [SkillDirectoryTarget] = [
            target("~/.claude/skills"),
            target("~/.claude/plugins/cache"),
            target("~/.claude/agents"),
            target("~/.codex/skills"),
            target("~/.codex/plugins/cache"),
            target("~/.hermes/skills"),
            target("~/.hermes/profiles"),
            target("~/.hermes/plugins"),
            target("~/.hermes/hermes-agent/optional-skills"),
            target("~/.openclaw/skills"),
            target("~/.agents/skills"),
            target("~/.pi/agent/skills"),
            target("~/.pi/agent/settings.json"),
            target("~/.pi/agent/node_modules"),
        ]

        if let hermesOptional = environment["HERMES_OPTIONAL_SKILLS"], !hermesOptional.isEmpty {
            targets.append(target(hermesOptional))
        }
        if let piHome = environment["PI_CODING_AGENT_DIR"], !piHome.isEmpty {
            targets.append(target((resolvePath(piHome) as NSString).appendingPathComponent("skills")))
            targets.append(target((resolvePath(piHome) as NSString).appendingPathComponent("settings.json")))
            targets.append(target((resolvePath(piHome) as NSString).appendingPathComponent("node_modules")))
        }

        for profileDir in hermesProfileDirectories() {
            targets.append(contentsOf: hermesExternalDirs(profileDir: profileDir).map(target))
            targets.append(contentsOf: hermesPluginSkillDirs(profileDir: profileDir).map(target))
        }

        let openClaw = openClawConfig()
        targets.append(target((openClaw.stateDir as NSString).appendingPathComponent("skills")))
        targets.append(contentsOf: openClaw.workspaces.flatMap { workspace in
            [
                target((workspace as NSString).appendingPathComponent("skills")),
                target((workspace as NSString).appendingPathComponent(".agents/skills")),
            ]
        })
        targets.append(contentsOf: openClaw.extraDirs.map(target))
        targets.append(contentsOf: openClaw.pluginSkillDirs.map(target))
        if let bundled = openClaw.bundledSkillsDir {
            targets.append(target(bundled))
        }

        let piHome = resolvePath(environment["PI_CODING_AGENT_DIR"] ?? "~/.pi/agent")
        for settingsPath in piSettingsPaths(piHome: piHome) {
            targets.append(contentsOf: piConfiguredSkillPaths(settingsPath: settingsPath).map(target))
        }
        targets.append(contentsOf: piPackageSkillDirs(piHome: piHome).map(target))

        return dedupeTargets(targets)
    }

    private func target(_ rawPath: String) -> SkillDirectoryTarget {
        SkillDirectoryTarget(displayPath: displayPath(for: rawPath), path: resolvePath(rawPath))
    }

    private func displayPath(for path: String) -> String {
        let resolved = resolvePath(path)
        if resolved == home { return "~" }
        if resolved.hasPrefix(home + "/") {
            return "~/" + String(resolved.dropFirst(home.count + 1))
        }
        return path.hasPrefix("~") ? path : resolved
    }

    private func resolvePath(_ path: String, relativeTo base: String? = nil) -> String {
        var value = path
        for (key, envValue) in environment {
            value = value.replacingOccurrences(of: "$\(key)", with: envValue)
            value = value.replacingOccurrences(of: "${\(key)}", with: envValue)
        }

        if value.hasPrefix("~") {
            value = (value as NSString).expandingTildeInPath
            if value.hasPrefix(NSHomeDirectory()) {
                value = home + String(value.dropFirst(NSHomeDirectory().count))
            }
        } else if let base, !value.hasPrefix("/") {
            value = (base as NSString).appendingPathComponent(value)
        }

        return (value as NSString).standardizingPath
    }

    private func shouldSkip(relativePath: String) -> Bool {
        relativePath.split(separator: "/").contains { shouldSkipComponent(String($0)) }
    }

    private func shouldSkipComponent(_ component: String) -> Bool {
        if component == "." || component == ".." { return true }
        if component.hasPrefix(".") {
            return component != ".agents"
        }
        return [
            "node_modules",
            "__pycache__",
            ".git",
            ".github",
            ".hub",
            ".bundled_manifest",
            ".pytest_cache",
            ".mypy_cache",
            ".ruff_cache",
            "DerivedData",
            "Library",
            "logs",
            "sessions",
            "state",
            "tmp",
            "cache",
            "caches",
        ].contains(component)
    }

    private func dedupeSkills(_ skills: [Skill]) -> [Skill] {
        var seen: Set<String> = []
        return skills.filter { seen.insert(($0.path as NSString).standardizingPath).inserted }
    }

    private func dedupePaths(_ paths: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for path in paths.map({ ($0 as NSString).standardizingPath }) where seen.insert(path).inserted {
            result.append(path)
        }
        return result
    }

    private func dedupeTargets(_ targets: [SkillDirectoryTarget]) -> [SkillDirectoryTarget] {
        var seen: Set<String> = []
        var result: [SkillDirectoryTarget] = []
        for target in targets where seen.insert(target.path).inserted {
            result.append(target)
        }
        return result
    }

    // MARK: - Lightweight Config Parsing

    private func parseYAMLStringList(content: String, path: [String]) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var sectionStack: [(indent: Int, key: String)] = []
        var results: [String] = []
        var collecting = false
        var targetIndent = 0

        for rawLine in lines {
            let lineWithoutComment = rawLine.components(separatedBy: "#").first ?? rawLine
            guard !lineWithoutComment.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let indent = lineWithoutComment.prefix(while: { $0 == " " }).count
            let stripped = lineWithoutComment.trimmingCharacters(in: .whitespaces)

            while let last = sectionStack.last, indent <= last.indent {
                sectionStack.removeLast()
            }

            if stripped.hasPrefix("-"), collecting, indent > targetIndent {
                let value = stripped.dropFirst().trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !value.isEmpty { results.append(value) }
                continue
            }

            guard let colon = stripped.firstIndex(of: ":") else { continue }
            let key = String(stripped[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(stripped[stripped.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            let currentPath = sectionStack.map(\.key) + [key]
            collecting = currentPath == path
            targetIndent = indent

            if collecting, value.hasPrefix("[") {
                results.append(contentsOf: parseInlineStringArray(value))
            }

            if value.isEmpty {
                sectionStack.append((indent, key))
            }
        }

        return results
    }

    private func extractStringArray(from object: [String: Any], paths: [[String]]) -> [String] {
        var results: [String] = []
        for path in paths {
            results.append(contentsOf: values(at: path, in: object).flatMap(stringArrayValue))
        }
        return results
    }

    private func values(at path: [String], in value: Any) -> [Any] {
        guard let first = path.first else { return [value] }
        let rest = Array(path.dropFirst())

        if let dict = value as? [String: Any] {
            if let nested = dict[first] {
                return values(at: rest, in: nested)
            }
            return []
        }

        if let array = value as? [Any] {
            return array.flatMap { element -> [Any] in
                if rest.isEmpty,
                   let dict = element as? [String: Any],
                   let nested = dict[first] {
                    return [nested]
                }
                return values(at: path, in: element)
            }
        }

        return []
    }

    private func stringArrayValue(_ value: Any?) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    private func parseInlineStringArray(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return array.compactMap { $0 as? String }
    }
}

private struct OpenClawResolvedConfig {
    var stateDir: String
    var workspaces: [String]
    var extraDirs: [String]
    var pluginSkillDirs: [String]
    var bundledSkillsDir: String?
}
