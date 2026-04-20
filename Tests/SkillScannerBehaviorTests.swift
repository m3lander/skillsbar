import Foundation

@main
struct SkillScannerBehaviorTests {
    static func main() throws {
        try testRecursiveDiscoverySkipsHiddenAndStateDirectories()
        try testHermesProfilesExternalPluginAndOptionalSkills()
        try testOpenClawConfiguredWorkspacesExtraDirsAndPluginSkills()
        try testOpenClawBunGlobalBundledSkills()
        try testPiConfiguredGlobalAndPackageManifestSkills()
        try testSharedAgentSkillsHaveSourceScopedIDs()
        try testReadOnlyAndDeletableClassification()
        print("SkillScannerBehaviorTests passed")
    }

    private static func testRecursiveDiscoverySkipsHiddenAndStateDirectories() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("home/.openclaw/skills/category/visible/SKILL.md", name: "visible-openclaw")
        try fixture.writeSkill("home/.openclaw/skills/.git/hidden/SKILL.md", name: "hidden-git")
        try fixture.writeSkill("home/.openclaw/skills/node_modules/pkg/SKILL.md", name: "hidden-node")
        try fixture.writeSkill("home/.openclaw/skills/.bundled_manifest/cached/SKILL.md", name: "hidden-manifest")

        let scanner = SkillScanner(home: fixture.home.path, environment: [:])
        let skills = scanner.scanAll()

        assertSkill(skills, named: "visible-openclaw", source: .openClaw(.managed))
        assertMissing(skills, named: "hidden-git")
        assertMissing(skills, named: "hidden-node")
        assertMissing(skills, named: "hidden-manifest")
    }

    private static func testHermesProfilesExternalPluginAndOptionalSkills() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("home/.hermes/skills/default-local/SKILL.md", name: "default-local")
        try fixture.writeSkill("home/hermes-external/external-one/SKILL.md", name: "external-one")
        try fixture.writeSkill("home/.hermes/plugins/weather/skills/plugin-one/SKILL.md", name: "plugin-one")
        try fixture.writeSkill("home/.hermes/profiles/coder/skills/profile-local/SKILL.md", name: "profile-local")
        try fixture.writeSkill("home/.hermes/profiles/coder/profile-external/external-two/SKILL.md", name: "external-two")
        try fixture.writeSkill("optional/official-one/SKILL.md", name: "official-one")
        try fixture.write(
            "home/.hermes/config.yaml",
            """
            skills:
              external_dirs:
                - ~/hermes-external
            """
        )
        try fixture.write(
            "home/.hermes/profiles/coder/config.yaml",
            """
            skills:
              external_dirs:
                - ~/.hermes/profiles/coder/profile-external
            """
        )

        let scanner = SkillScanner(
            home: fixture.home.path,
            environment: ["HERMES_OPTIONAL_SKILLS": fixture.url("optional").path]
        )
        let skills = scanner.scanAll()

        assertSkill(skills, named: "default-local", source: .hermes(.profileLocal))
        assertSkill(skills, named: "profile-local", source: .hermes(.profileLocal))
        assertSkill(skills, named: "external-one", source: .hermes(.external))
        assertSkill(skills, named: "external-two", source: .hermes(.external))
        assertSkill(skills, named: "plugin-one", source: .hermes(.plugin))
        assertSkill(skills, named: "official-one", source: .hermes(.optional))
    }

    private static func testOpenClawConfiguredWorkspacesExtraDirsAndPluginSkills() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("workspace/skills/workspace-one/SKILL.md", name: "workspace-one")
        try fixture.writeSkill("workspace/.agents/skills/project-agent-one/SKILL.md", name: "project-agent-one")
        try fixture.writeSkill("home/.agents/skills/personal-agent-one/SKILL.md", name: "personal-agent-one")
        try fixture.writeSkill("home/.openclaw/skills/managed-one/SKILL.md", name: "managed-one")
        try fixture.writeSkill("home/openclaw-extra/extra-one/SKILL.md", name: "extra-one")
        try fixture.writeSkill("home/openclaw-plugins/weather/skills/plugin-one/SKILL.md", name: "openclaw-plugin-one")
        try fixture.write("home/openclaw-plugins/weather/openclaw.plugin.json", #"{"skills":["skills"]}"#)
        try fixture.write(
            "home/.openclaw/openclaw.json",
            """
            {
              "workspaces": ["\(fixture.url("workspace").path)"],
              "skills": { "load": { "extraDirs": ["~/openclaw-extra"] } },
              "plugins": { "dirs": ["~/openclaw-plugins"] }
            }
            """
        )

        let scanner = SkillScanner(home: fixture.home.path, environment: [:])
        let skills = scanner.scanAll()

        assertSkill(skills, named: "workspace-one", source: .openClaw(.workspace))
        assertSkill(skills, named: "project-agent-one", source: .openClaw(.projectAgents))
        assertSkill(skills, named: "personal-agent-one", source: .openClaw(.personalAgents))
        assertSkill(skills, named: "managed-one", source: .openClaw(.managed))
        assertSkill(skills, named: "extra-one", source: .openClaw(.extra))
        assertSkill(skills, named: "openclaw-plugin-one", source: .openClaw(.plugin))
    }

    private static func testOpenClawBunGlobalBundledSkills() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("home/.bun/install/global/node_modules/openclaw/skills/bundled-one/SKILL.md", name: "bundled-one")

        let scanner = SkillScanner(home: fixture.home.path, environment: [:])
        let skills = scanner.scanAll()
        let watched = scanner.watchedDirectories()

        assertSkill(skills, named: "bundled-one", source: .openClaw(.bundled))
        assertWatched(watched, path: fixture.url("home/.bun/install/global/node_modules/openclaw/skills").path)
    }

    private static func testPiConfiguredGlobalAndPackageManifestSkills() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("custom-pi/skills/pi-home-one/SKILL.md", name: "pi-home-one")
        try fixture.writeSkill("home/.agents/skills/pi-agent-one/SKILL.md", name: "pi-agent-one")
        try fixture.writeSkill("home/pi-configured/configured-one/SKILL.md", name: "configured-one")
        try fixture.writeSkill("home/.pi/agent/node_modules/pkg/skills/package-one/SKILL.md", name: "package-one")
        try fixture.write(
            "home/.pi/agent/settings.json",
            #"{"skills":["~/pi-configured"]}"#
        )
        try fixture.write(
            "home/.pi/agent/node_modules/pkg/package.json",
            #"{"name":"pkg","pi":{"skills":["skills"]}}"#
        )

        let scanner = SkillScanner(
            home: fixture.home.path,
            environment: ["PI_CODING_AGENT_DIR": fixture.url("custom-pi").path]
        )
        let skills = scanner.scanAll()

        assertSkill(skills, named: "pi-home-one", source: .pi(.agentHome))
        assertSkill(skills, named: "pi-agent-one", source: .pi(.personalAgents))
        assertSkill(skills, named: "configured-one", source: .pi(.settings))
        assertSkill(skills, named: "package-one", source: .pi(.package))
    }

    private static func testSharedAgentSkillsHaveSourceScopedIDs() throws {
        let fixture = try Fixture()
        try fixture.writeSkill("home/.agents/skills/shared-one/SKILL.md", name: "shared-one")

        let scanner = SkillScanner(home: fixture.home.path, environment: [:])
        let matches = scanner.scanAll()
            .filter { $0.path == fixture.url("home/.agents/skills/shared-one/SKILL.md").path }

        XCTAssertEqual(matches.count, 2, "Expected shared agent skill to appear for OpenClaw and Pi")
        XCTAssertTrue(matches.contains { $0.source == .openClaw(.personalAgents) }, "Expected OpenClaw shared agent skill")
        XCTAssertTrue(matches.contains { $0.source == .pi(.personalAgents) }, "Expected Pi shared agent skill")
        XCTAssertEqual(Set(matches.map(\.id)).count, matches.count, "Same-path skills from different sources should have distinct IDs")
    }

    private static func testReadOnlyAndDeletableClassification() throws {
        XCTAssertFalse(SkillSource.claudeCode(.user).isReadOnly, "Claude user skills should be writable")
        XCTAssertTrue(SkillSource.claudeCode(.user).isDeletable, "Claude user skills should be deletable")
        XCTAssertTrue(SkillSource.codexCLI(.plugin).isReadOnly, "Codex plugin skills should be read-only")
        XCTAssertFalse(SkillSource.codexCLI(.plugin).isDeletable, "Codex plugin skills should not be deletable")
        XCTAssertFalse(SkillSource.hermes(.profileLocal).isReadOnly, "Hermes profile skills should be writable")
        XCTAssertTrue(SkillSource.hermes(.optional).isReadOnly, "Hermes optional skills should be read-only")
        XCTAssertTrue(SkillSource.openClaw(.workspace).isDeletable, "OpenClaw workspace skills should be deletable")
        XCTAssertFalse(SkillSource.openClaw(.extra).isDeletable, "OpenClaw extra dir skills should not be deletable")
        XCTAssertFalse(SkillSource.pi(.package).isDeletable, "Pi package skills should not be deletable")
    }

    private static func assertSkill(_ skills: [Skill], named name: String, source: SkillSource) {
        guard skills.contains(where: { $0.name == name && $0.source == source }) else {
            fail("Expected skill '\(name)' from \(source), got \(skills.map { "\($0.name):\($0.source)" }.sorted())")
        }
    }

    private static func assertMissing(_ skills: [Skill], named name: String) {
        guard !skills.contains(where: { $0.name == name }) else {
            fail("Expected skill '\(name)' to be skipped")
        }
    }

    private static func assertWatched(_ targets: [SkillDirectoryTarget], path: String) {
        guard targets.contains(where: { $0.path == path }) else {
            fail("Expected watched path '\(path)', got \(targets.map(\.path).sorted())")
        }
    }

    private static func XCTAssertTrue(_ condition: Bool, _ message: String) {
        if !condition { fail(message) }
    }

    private static func XCTAssertFalse(_ condition: Bool, _ message: String) {
        if condition { fail(message) }
    }

    private static func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected { fail("\(message): expected \(expected), got \(actual)") }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}

private final class Fixture {
    let root: URL
    let home: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skillsbar-scanner-tests-\(UUID().uuidString)", isDirectory: true)
        home = root.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    func write(_ relativePath: String, _ content: String) throws {
        let fileURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func writeSkill(_ relativePath: String, name: String) throws {
        try write(
            relativePath,
            """
            ---
            name: \(name)
            description: \(name) description
            ---

            # \(name)
            """
        )
    }
}
