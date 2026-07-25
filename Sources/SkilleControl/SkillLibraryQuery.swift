import Foundation

public enum SkillScopeFilter: String, CaseIterable, Sendable {
    case all
    case global
    case project
}

public enum SkillProvenanceFilter: String, CaseIterable, Sendable {
    case all
    case sourced
    case orphan
}

public struct SkillLibraryResult: Equatable, Sendable {
    public let skills: [SkillSummary]
    public let selection: String?
}

public struct SkillLibraryQuery: Equatable, Sendable {
    public var text: String
    public var adapterId: String?
    public var scope: SkillScopeFilter
    public var provenance: SkillProvenanceFilter
    public var updatesOnly: Bool
    public var dirtyOnly: Bool

    public init(
        text: String = "",
        adapterId: String? = nil,
        scope: SkillScopeFilter = .all,
        provenance: SkillProvenanceFilter = .all,
        updatesOnly: Bool = false,
        dirtyOnly: Bool = false
    ) {
        self.text = text
        self.adapterId = adapterId
        self.scope = scope
        self.provenance = provenance
        self.updatesOnly = updatesOnly
        self.dirtyOnly = dirtyOnly
    }

    public var activeFilterCount: Int {
        (adapterId == nil ? 0 : 1)
            + (scope == .all ? 0 : 1)
            + (provenance == .all ? 0 : 1)
            + (updatesOnly ? 1 : 0)
            + (dirtyOnly ? 1 : 0)
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && activeFilterCount == 0
    }

    public func apply(to skills: [SkillSummary], selection: String?) -> SkillLibraryResult {
        let matches = skills.filter(matches)
        return SkillLibraryResult(
            skills: matches,
            selection: selection.flatMap { id in
                matches.contains(where: { $0.id == id }) ? id : nil
            }
        )
    }

    private func matches(_ skill: SkillSummary) -> Bool {
        if let adapterId, !skill.adapterIds.contains(adapterId) { return false }
        if scope != .all, !skill.scopes.contains(scope.rawValue) { return false }
        if provenance == .sourced, skill.isOrphan { return false }
        if provenance == .orphan, !skill.isOrphan { return false }
        if updatesOnly, !skill.hasUpdate { return false }
        if dirtyOnly, !skill.isDirty { return false }

        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let fields = [
            skill.displayName,
            skill.sourceName,
            AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds),
        ].compactMap { $0 } + skill.adapterIds + skill.skillRootPaths + skill.locationPaths
        return fields.contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}
