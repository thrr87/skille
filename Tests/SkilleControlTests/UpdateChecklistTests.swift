import Foundation
import Testing
@testable import SkilleControl

struct UpdateChecklistTests {
    @Test func listsOnlyLocationsWithUpdates() throws {
        let env = try ReviewFixture()
        defer { env.cleanup() }

        // No tip change yet
        var items = try env.plane.locationsNeedingUpdate(sourceId: env.sourceId)
        #expect(items.isEmpty)

        try env.bumpRemote(content: "# Handy v2\n")
        _ = try env.plane.checkUpdates()
        items = try env.plane.locationsNeedingUpdate(sourceId: env.sourceId)
        #expect(items.map(\.locationId) == [env.locationId])
        #expect(items[0].displayName == "handy")
    }

    @Test func checklistSelectionPreparesSharedReview() throws {
        let env = try ReviewFixture()
        defer { env.cleanup() }

        try env.bumpRemote(content: "# Handy v2\n")
        _ = try env.plane.checkUpdates()
        let items = try env.plane.locationsNeedingUpdate(sourceId: env.sourceId)
        let selected = items.map(\.locationId)
        let reviews = try env.plane.prepareUpdateReviews(locationIds: selected)
        #expect(reviews.count == 1)
        #expect(reviews[0].locationId == env.locationId)
        #expect(reviews[0].files.contains { $0.status == .modified })
    }
}
