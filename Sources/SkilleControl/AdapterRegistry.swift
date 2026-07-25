import Foundation

/// Vendor-verified v1 adapters (research: v1-adapter-registry.md).
public struct AdapterDescriptor: Sendable, Equatable {
    public let id: String
    /// Paths relative to home (or absolute) that mark the agent as present.
    public let detectRelativePaths: [String]
    /// Global skill roots relative to home to walk for SKILL.md packages.
    public let globalSkillRoots: [String]
}

public enum AdapterRegistry {
    public static let v1: [AdapterDescriptor] = [
        AdapterDescriptor(
            id: "cursor",
            detectRelativePaths: [".cursor"],
            globalSkillRoots: [".agents/skills", ".cursor/skills"]
        ),
        AdapterDescriptor(
            id: "claude-code",
            detectRelativePaths: [".claude"],
            globalSkillRoots: [".claude/skills"]
        ),
        AdapterDescriptor(
            id: "codex",
            detectRelativePaths: [".codex"],
            globalSkillRoots: [".agents/skills", ".codex/skills"]
        ),
        AdapterDescriptor(
            id: "gemini-cli",
            detectRelativePaths: [".gemini"],
            globalSkillRoots: [".agents/skills", ".gemini/skills"]
        ),
        AdapterDescriptor(
            id: "opencode",
            detectRelativePaths: [".config/opencode"],
            globalSkillRoots: [".agents/skills", ".config/opencode/skills", ".claude/skills"]
        ),
        AdapterDescriptor(
            id: "goose",
            detectRelativePaths: [".config/goose"],
            globalSkillRoots: [".agents/skills", ".claude/skills", ".config/goose/skills"]
        ),
        AdapterDescriptor(
            id: "copilot",
            detectRelativePaths: [".copilot"],
            globalSkillRoots: [".copilot/skills", ".agents/skills"]
        ),
        AdapterDescriptor(
            id: "amp",
            detectRelativePaths: [".config/amp"],
            globalSkillRoots: [
                ".config/agents/skills",
                ".agents/skills",
                ".config/amp/skills",
                ".claude/skills",
            ]
        ),
    ]
}
