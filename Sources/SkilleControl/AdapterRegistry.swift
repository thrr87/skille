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
}

public enum AdapterRegistry {
    public static let v1: [AdapterDescriptor] = [
        AdapterDescriptor(
            id: "cursor",
            detectRelativePaths: [".cursor"],
            globalSkillRoots: [".agents/skills", ".cursor/skills"],
            projectSkillRoots: [".agents/skills", ".cursor/skills"]
        ),
        AdapterDescriptor(
            id: "claude-code",
            detectRelativePaths: [".claude"],
            globalSkillRoots: [".claude/skills"],
            projectSkillRoots: [".claude/skills"]
        ),
        AdapterDescriptor(
            id: "codex",
            detectRelativePaths: [".codex"],
            globalSkillRoots: [".agents/skills", ".codex/skills"],
            projectSkillRoots: [".agents/skills"]
        ),
        AdapterDescriptor(
            id: "gemini-cli",
            detectRelativePaths: [".gemini"],
            globalSkillRoots: [".agents/skills", ".gemini/skills"],
            projectSkillRoots: [".agents/skills", ".gemini/skills"]
        ),
        AdapterDescriptor(
            id: "opencode",
            detectRelativePaths: [".config/opencode"],
            globalSkillRoots: [".agents/skills", ".config/opencode/skills", ".claude/skills"],
            projectSkillRoots: [".agents/skills", ".opencode/skills", ".claude/skills"]
        ),
        AdapterDescriptor(
            id: "goose",
            detectRelativePaths: [".config/goose"],
            globalSkillRoots: [".agents/skills", ".claude/skills", ".config/goose/skills"],
            projectSkillRoots: [".agents/skills", ".goose/skills", ".claude/skills"]
        ),
        AdapterDescriptor(
            id: "copilot",
            detectRelativePaths: [".copilot"],
            globalSkillRoots: [".copilot/skills", ".agents/skills"],
            projectSkillRoots: [".github/skills", ".agents/skills", ".claude/skills"]
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
            projectSkillRoots: [".agents/skills", ".claude/skills"]
        ),
    ]

    /// Distinct project-relative roots across all adapters (no full-disk crawl).
    public static var allProjectSkillRoots: [String] {
        Array(Set(v1.flatMap(\.projectSkillRoots))).sorted()
    }
}
