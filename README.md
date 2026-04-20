<p align="center">
  <img src="screenshots/app-icon.png" width="128" height="128" alt="SkillsBar icon" />
</p>

<h1 align="center">SkillsBar</h1>

<p align="center">
  A macOS menu bar app for browsing and managing your <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>, <a href="https://github.com/openai/codex">Codex CLI</a>, Hermes, OpenClaw, and Pi skills, plugins, collections, and agents.
</p>

<p align="center">
  <img src="https://img.shields.io/github/downloads/amandeepmittal/skillsbar/total?style=flat-square&label=downloads" alt="GitHub Downloads" />
</p>

## Screenshots

<p align="center">
  <img src="screenshots/list-view.png" width="320" alt="Claude Code skills" />
  &nbsp;&nbsp;
  <img src="screenshots/codex-tab.png" width="320" alt="Codex skills and plugins" />
  &nbsp;&nbsp;
  <img src="screenshots/detail-view.png" width="320" alt="Skill detail view" />
  &nbsp;&nbsp;
  <img src="screenshots/usage-stats.png" width="320" alt="Usage stats" />
  &nbsp;&nbsp;
  <img src="screenshots/about-view.png" width="320" alt="About view with watched directories" />
  &nbsp;&nbsp;
  <img src="screenshots/collections-1.png" width="320" alt="Collections view" />
  &nbsp;&nbsp;
  <img src="screenshots/collections-2.png" width="320" alt="Collection detail view" />
  &nbsp;&nbsp;
  <img src="screenshots/collections-3.png" width="320" alt="Collection detail view" />
</p>

## Features

- **Tabbed browsing** - separate tabs for Claude Code, Codex, Hermes, OpenClaw, Pi, and Collections with count badges
- **Search** - filter skills, plugins, and collections by name, description, or trigger
- **Pin favorites** - pin frequently used skills to the top of each tab (persisted across restarts)
- **Settings** - choose whether to show What's New, switch between system, light, and dark appearance, and control the default sort from one place
- **Sort options** - sort skills by A-Z, Recently Modified, or Most Used, with the selected order persisted across restarts
- **Collections** - create custom cross-source groups that can mix skills from all supported tools in one saved view
- **Codex plugin browsing** - browse installed Codex plugins with version, publisher, capabilities, included skills, and quick open/reveal actions
- **What's New** - spotlight skills and installed plugins changed in the last 7 days in a dedicated section
- **Usage stats** - tracks skill invocations from Claude Code and Codex CLI history, including Codex plugin skills, with source-aware insights, summary breakdowns, and ranked per-skill usage sections
- **"New" indicator** - skills modified in the last 24 hours are marked with a blue badge
- **Detail views** - inspect rich metadata for skills, agents, and Codex plugins, including trigger commands, included skills, file listings, and source/deletability labels
- **Full content preview** - expandable section to view the raw SKILL.md body
- **Quick actions** - open in VS Code, open in default editor, copy path, reveal in Finder, and manage items from the list
- **Right-click context menu** - pin, add to collections, open, copy, and delete writable skills directly from the list
- **About & utilities** - view watched directories, library counts, and reveal watched folders directly in Finder from the About screen
- **Global hotkey** - toggle the popover from anywhere with `Option + Shift + S`
- **Agent browsing** - browse Claude Code sub-agents (user and plugin) with model, color, and tools metadata
- **Live updates** - FSEvents directory watcher auto-refreshes when skills, plugins, configured workspaces, or agents are added or removed
- **No dock icon** - lives entirely in the menu bar

## Watched Directories

| Path                       | Source                                     |
| -------------------------- | ------------------------------------------ |
| `~/.claude/skills/`        | Claude Code user skills                    |
| `~/.claude/plugins/cache/` | Claude Code plugin skills                  |
| `~/.claude/agents/`        | Claude Code user agents                    |
| `~/.codex/skills/`         | Codex CLI built-in and user skills         |
| `~/.codex/plugins/cache/`  | Codex CLI plugins and plugin-provided skills |
| `~/.hermes/skills/`        | Hermes default profile skills              |
| `~/.hermes/profiles/`      | Hermes named profile skills and config     |
| `~/.hermes/plugins/`       | Hermes plugin-bundled read-only skills     |
| `~/.hermes/hermes-agent/optional-skills/` or `HERMES_OPTIONAL_SKILLS` | Hermes official optional skills |
| `~/.openclaw/skills/` or `OPENCLAW_STATE_DIR/skills` | OpenClaw managed skills |
| `~/.bun/install/global/node_modules/openclaw/skills/` or `OPENCLAW_BUNDLED_SKILLS_DIR` | OpenClaw bundled read-only skills |
| OpenClaw configured workspaces | `<workspace>/skills` and `<workspace>/.agents/skills` from `~/.openclaw/openclaw.json` or `OPENCLAW_CONFIG_PATH` |
| OpenClaw `skills.load.extraDirs` | Configured OpenClaw extra skill directories |
| OpenClaw plugin `openclaw.plugin.json` skill dirs | Plugin-declared read-only skill directories |
| `~/.agents/skills/`        | Shared personal agent skills for OpenClaw and Pi |
| `PI_CODING_AGENT_DIR/skills` or `~/.pi/agent/skills/` | Pi agent skills |
| `~/.pi/agent/settings.json` `skills[]` | Pi configured skill paths |
| `~/.pi/agent/node_modules/**/package.json` `pi.skills` | Pi installed package skills |

OpenClaw and Pi workspace discovery is intentionally configured-only. SkillsBar reads OpenClaw workspace paths from config and Pi paths from global/settings/package manifests; it does not broadly scan arbitrary project folders for `.pi/skills` or ancestor `.agents/skills`.

## Install

1. Download `SkillsBar-vX.X.X.zip` from the [latest release](https://github.com/amandeepmittal/skillsbar/releases/latest)
2. Unzip and move `SkillsBar.app` to your Applications folder
3. Remove the quarantine flag (required once for unsigned builds):
   ```bash
   xattr -cr /Applications/SkillsBar.app
   ```
4. Open `SkillsBar.app` from Applications or Spotlight

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (to build from source)

## Tech Stack

- Swift 5.9, SwiftUI
- `NSStatusItem` + `NSPopover` for menu bar integration
- `FSEventStream` (CoreServices) for live directory watching
- Carbon `RegisterEventHotKey` for global keyboard shortcut
- Regex-based YAML frontmatter parser (no third-party dependencies)

## License

Apache-2.0

## Author

[Aman Mittal](https://amanhimself.dev)
