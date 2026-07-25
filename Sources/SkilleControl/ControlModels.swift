import Foundation

public struct ScanResult: Equatable, Sendable {
    public let skillsFound: Int
    public let rootsFound: Int
    public let detectedAdapterIds: [String]
    public let inventoryChanged: Bool

    public init(
        skillsFound: Int,
        rootsFound: Int,
        detectedAdapterIds: [String],
        inventoryChanged: Bool
    ) {
        self.skillsFound = skillsFound
        self.rootsFound = rootsFound
        self.detectedAdapterIds = detectedAdapterIds
        self.inventoryChanged = inventoryChanged
    }
}

public struct UpdateCheckResult: Equatable, Sendable {
    public let updatesFound: Int
    public let dirtyFound: Int

    public init(updatesFound: Int, dirtyFound: Int) {
        self.updatesFound = updatesFound
        self.dirtyFound = dirtyFound
    }
}

public enum InstallError: Error, Equatable {
    case sourceNotFound
    case packageNotFound(String)
    case rootNotFound(String)
}

public enum AuthoringError: Error, Equatable {
    case invalidName
    case alreadyExists(String)
}

public enum UpdateReviewError: Error, Equatable {
    case locationNotFound
    case noProvenance
    case remoteMissing
    case dirtyRequiresDiscard
}

public enum AttachSourceError: Error, Equatable {
    case locationNotFound
    case notOrphan
    case confirmationRequired
}

public enum UpdateFileStatus: String, Equatable, Sendable {
    case added
    case modified
    case deleted
}

public struct UpdateFileChange: Identifiable, Equatable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String
    public let status: UpdateFileStatus
    public let textDiff: String?
    public let oldByteSize: Int?
    public let newByteSize: Int?

    public init(
        relativePath: String,
        status: UpdateFileStatus,
        textDiff: String?,
        oldByteSize: Int?,
        newByteSize: Int?
    ) {
        self.relativePath = relativePath
        self.status = status
        self.textDiff = textDiff
        self.oldByteSize = oldByteSize
        self.newByteSize = newByteSize
    }
}

public struct UpdateReview: Equatable, Sendable {
    public let locationId: String
    public let displayName: String
    public let onDiskPath: String
    public let proposedCommitSHA: String
    public let appliedCommitSHA: String?
    public let isDirty: Bool
    public let files: [UpdateFileChange]

    public init(
        locationId: String,
        displayName: String,
        onDiskPath: String,
        proposedCommitSHA: String,
        appliedCommitSHA: String?,
        isDirty: Bool,
        files: [UpdateFileChange]
    ) {
        self.locationId = locationId
        self.displayName = displayName
        self.onDiskPath = onDiskPath
        self.proposedCommitSHA = proposedCommitSHA
        self.appliedCommitSHA = appliedCommitSHA
        self.isDirty = isDirty
        self.files = files
    }
}

public struct UpdateChecklistItem: Identifiable, Equatable, Sendable {
    public var id: String { locationId }
    public let locationId: String
    public let displayName: String
    public let onDiskPath: String
    public let isDirty: Bool

    public init(locationId: String, displayName: String, onDiskPath: String, isDirty: Bool) {
        self.locationId = locationId
        self.displayName = displayName
        self.onDiskPath = onDiskPath
        self.isDirty = isDirty
    }
}

public enum EditorError: Error, Equatable {
    case rootMissing
    case fileMissing
    case pathEscape
}

public struct SkillFileEntry: Identifiable, Equatable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String

    public init(relativePath: String) {
        self.relativePath = relativePath
    }
}

public enum SkillFileKind: Equatable, Sendable {
    case text(String)
    case nonText
    case tooLarge
}

public struct SkillFileContent: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int
    public let kind: SkillFileKind

    public init(relativePath: String, byteSize: Int, kind: SkillFileKind) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.kind = kind
    }
}

public struct SkillSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let locationCount: Int
    public let isOrphan: Bool
    public let hasUpdate: Bool
    public let isDirty: Bool
    public let isFromProject: Bool

    public init(
        id: String,
        displayName: String,
        locationCount: Int = 1,
        isOrphan: Bool = true,
        hasUpdate: Bool = false,
        isDirty: Bool = false,
        isFromProject: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.locationCount = locationCount
        self.isOrphan = isOrphan
        self.hasUpdate = hasUpdate
        self.isDirty = isDirty
        self.isFromProject = isFromProject
    }
}

public struct LocationSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let onDiskPath: String
    public let skillRootPath: String
    public let adapterIds: [String]
    public let appliedCommitSHA: String?
    public let fileDigests: [FileDigestRecord]

    public init(
        id: String,
        onDiskPath: String,
        skillRootPath: String,
        adapterIds: [String],
        appliedCommitSHA: String? = nil,
        fileDigests: [FileDigestRecord] = []
    ) {
        self.id = id
        self.onDiskPath = onDiskPath
        self.skillRootPath = skillRootPath
        self.adapterIds = adapterIds
        self.appliedCommitSHA = appliedCommitSHA
        self.fileDigests = fileDigests
    }
}

public struct InstallRootOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let isDefaultSuggestion: Bool

    public init(id: String, path: String, isDefaultSuggestion: Bool) {
        self.id = id
        self.path = path
        self.isDefaultSuggestion = isDefaultSuggestion
    }
}

public struct SkillDetail: Equatable, Sendable {
    public let summary: SkillSummary
    public let locations: [LocationSummary]

    public init(summary: SkillSummary, locations: [LocationSummary]) {
        self.summary = summary
        self.locations = locations
    }
}

public struct SkillSourceSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let normalizedUrl: String
    public let branch: String
    public let hasUpdate: Bool

    public init(
        id: String,
        displayName: String,
        normalizedUrl: String,
        branch: String,
        hasUpdate: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedUrl = normalizedUrl
        self.branch = branch
        self.hasUpdate = hasUpdate
    }
}

public enum PackageInstallStatus: String, Equatable, Sendable {
    case notInstalled
    case installed
}

public struct SourcePackage: Identifiable, Equatable, Sendable {
    public var id: String { pathInRepo }
    public let pathInRepo: String
    public let displayName: String
    public let installStatus: PackageInstallStatus

    public init(pathInRepo: String, displayName: String, installStatus: PackageInstallStatus) {
        self.pathInRepo = pathInRepo
        self.displayName = displayName
        self.installStatus = installStatus
    }
}

public struct SourceDetail: Equatable, Sendable {
    public let summary: SkillSourceSummary
    public let packages: [SourcePackage]

    public init(summary: SkillSourceSummary, packages: [SourcePackage]) {
        self.summary = summary
        self.packages = packages
    }
}
