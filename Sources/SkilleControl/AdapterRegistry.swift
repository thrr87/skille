import Foundation

/// Vendor-verified v1 adapters (research: v1-adapter-registry.md).
public struct AdapterDescriptor: Sendable, Equatable {
    public let id: String
    /// Paths relative to home (or absolute) that mark the agent as present.
    public let detectRelativePaths: [String]
    /// Global skill roots relative to home to walk for SKILL.md packages.
    public let globalSkillRoots: [String]
    /// Project-relative skill roots (only scanned for user-added Projects).
    public let projectSkillRoots: [String]
    /// Roots walked recursively for nested packages (plugin caches, etc.).
    public let deepGlobalSkillRoots: [String]
    /// Roots Skille may create or write into for this adapter.
    public let writableGlobalSkillRoots: [String]
    public let writableProjectSkillRoots: [String]

    public init(
        id: String,
        detectRelativePaths: [String],
        globalSkillRoots: [String],
        projectSkillRoots: [String],
        deepGlobalSkillRoots: [String] = [],
        writableGlobalSkillRoots: [String],
        writableProjectSkillRoots: [String]
    ) {
        self.id = id
        self.detectRelativePaths = detectRelativePaths
        self.globalSkillRoots = globalSkillRoots
        self.projectSkillRoots = projectSkillRoots
        self.deepGlobalSkillRoots = deepGlobalSkillRoots
        self.writableGlobalSkillRoots = writableGlobalSkillRoots
        self.writableProjectSkillRoots = writableProjectSkillRoots
    }
}

public enum AdapterRegistry {
    public static let v1: [AdapterDescriptor] = [
        AdapterDescriptor(
            id: "cursor",
            detectRelativePaths: [".cursor"],
            globalSkillRoots: [".agents/skills", ".cursor/skills", ".cursor/skills-cursor"],
            projectSkillRoots: [".agents/skills", ".cursor/skills"],
            deepGlobalSkillRoots: [".cursor/plugins"],
            writableGlobalSkillRoots: [".agents/skills", ".cursor/skills"],
            writableProjectSkillRoots: [".agents/skills", ".cursor/skills"]
        ),
        AdapterDescriptor(
            id: "claude-code",
            detectRelativePaths: [".claude"],
            globalSkillRoots: [".claude/skills"],
            projectSkillRoots: [".claude/skills"],
            deepGlobalSkillRoots: [".claude/plugins"],
            writableGlobalSkillRoots: [".claude/skills"],
            writableProjectSkillRoots: [".claude/skills"]
        ),
        AdapterDescriptor(
            id: "codex",
            detectRelativePaths: [".codex"],
            globalSkillRoots: [".agents/skills", ".codex/skills"],
            projectSkillRoots: [".agents/skills"],
            writableGlobalSkillRoots: [".agents/skills"],
            writableProjectSkillRoots: [".agents/skills"]
        ),
        AdapterDescriptor(
            id: "gemini-cli",
            detectRelativePaths: [".gemini"],
            globalSkillRoots: [".agents/skills", ".gemini/skills"],
            projectSkillRoots: [".agents/skills", ".gemini/skills"],
            writableGlobalSkillRoots: [".agents/skills", ".gemini/skills"],
            writableProjectSkillRoots: [".agents/skills", ".gemini/skills"]
        ),
        AdapterDescriptor(
            id: "opencode",
            detectRelativePaths: [".config/opencode"],
            globalSkillRoots: [".agents/skills", ".config/opencode/skills", ".claude/skills"],
            projectSkillRoots: [".agents/skills", ".opencode/skills", ".claude/skills"],
            writableGlobalSkillRoots: [".agents/skills", ".config/opencode/skills"],
            writableProjectSkillRoots: [".agents/skills", ".opencode/skills"]
        ),
        AdapterDescriptor(
            id: "goose",
            detectRelativePaths: [".config/goose"],
            globalSkillRoots: [".agents/skills", ".claude/skills", ".config/goose/skills"],
            projectSkillRoots: [".agents/skills", ".goose/skills", ".claude/skills"],
            writableGlobalSkillRoots: [".agents/skills", ".config/goose/skills"],
            writableProjectSkillRoots: [".agents/skills", ".goose/skills"]
        ),
        AdapterDescriptor(
            id: "copilot",
            detectRelativePaths: [".copilot"],
            globalSkillRoots: [".copilot/skills", ".agents/skills"],
            projectSkillRoots: [".github/skills", ".agents/skills", ".claude/skills"],
            writableGlobalSkillRoots: [".agents/skills", ".copilot/skills"],
            writableProjectSkillRoots: [".agents/skills", ".github/skills"]
        ),
        AdapterDescriptor(
            id: "amp",
            detectRelativePaths: [".config/amp"],
            globalSkillRoots: [
                ".config/agents/skills",
                ".agents/skills",
                ".config/amp/skills",
                ".claude/skills",
            ],
            projectSkillRoots: [".agents/skills", ".claude/skills"],
            writableGlobalSkillRoots: [
                ".agents/skills",
                ".config/agents/skills",
                ".config/amp/skills",
            ],
            writableProjectSkillRoots: [".agents/skills"]
        ),
    ]

    /// Distinct project-relative roots across all adapters (no full-disk crawl).
    public static var allProjectSkillRoots: [String] {
        Array(Set(v1.flatMap(\.projectSkillRoots))).sorted()
    }

    public static func displayName(forAdapterId id: String) -> String {
        switch id {
        case "cursor": return "Cursor"
        case "claude-code": return "Claude Code"
        case "codex": return "Codex"
        case "gemini-cli": return "Gemini CLI"
        case "opencode": return "OpenCode"
        case "goose": return "Goose"
        case "copilot": return "Copilot"
        case "amp": return "Amp"
        default: return id
        }
    }

    public static func displayNames(forAdapterIds ids: [String]) -> String {
        ids.map(displayName(forAdapterId:)).joined(separator: " · ")
    }
}
