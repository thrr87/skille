import Foundation

public enum EditorNavigationDecision: Sendable {
    case save
    case discard
    case cancel
}

public struct EditorSession: Sendable {
    private let controlPlane: ControlPlane
    public private(set) var skillRootPath: String?
    public private(set) var relativePath: String?
    public private(set) var fileKind: SkillFileKind = .text("")
    public private(set) var originalBuffer = ""
    public private(set) var hasPendingNavigation = false
    public var buffer = ""

    public init(controlPlane: ControlPlane) {
        self.controlPlane = controlPlane
    }

    public var isDirty: Bool {
        guard case .text = fileKind else { return false }
        return buffer != originalBuffer
    }

    public mutating func open(skillRootPath: String, relativePath: String) throws {
        let content = try controlPlane.readTextFile(
            at: skillRootPath,
            relativePath: relativePath
        )
        self.skillRootPath = skillRootPath
        self.relativePath = relativePath
        fileKind = content.kind
        if case let .text(text) = content.kind {
            buffer = text
            originalBuffer = text
        } else {
            buffer = ""
            originalBuffer = ""
        }
        hasPendingNavigation = false
    }

    public mutating func save() throws {
        guard let skillRootPath, let relativePath, case .text = fileKind else { return }
        try controlPlane.writeTextFile(
            at: skillRootPath,
            relativePath: relativePath,
            content: buffer
        )
        originalBuffer = buffer
    }

    public mutating func requestNavigation() -> Bool {
        guard isDirty else { return true }
        hasPendingNavigation = true
        return false
    }

    public mutating func resolveNavigation(_ decision: EditorNavigationDecision) throws -> Bool {
        guard hasPendingNavigation else { return true }
        switch decision {
        case .save:
            try save()
        case .discard:
            buffer = originalBuffer
        case .cancel:
            hasPendingNavigation = false
            return false
        }
        hasPendingNavigation = false
        return true
    }
}
