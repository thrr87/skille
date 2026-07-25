import Foundation

public enum MarkdownPreview {
    public enum BlockKind: Equatable, Sendable {
        case heading(level: Int)
        case paragraph
        case unorderedListItem
        case orderedListItem(ordinal: Int)
        case codeBlock(language: String?)
    }

    public struct Block: Equatable, Sendable {
        public let kind: BlockKind
        public var content: AttributedString
    }

    public static func blocks(fromSkillMarkdown source: String) throws -> [Block] {
        let parsed = try AttributedString(
            markdown: body(afterFrontmatterIn: source),
            options: .init(failurePolicy: .returnPartiallyParsedIfPossible)
        )
        var blocks: [Block] = []
        var identities: [Int] = []

        for run in parsed.runs {
            guard let intent = run.presentationIntent else { continue }
            let descriptor = blockDescriptor(for: intent)
            let fragment = AttributedString(parsed[run.range])
            if identities.last == descriptor.identity {
                blocks[blocks.count - 1].content.append(fragment)
            } else {
                identities.append(descriptor.identity)
                blocks.append(Block(kind: descriptor.kind, content: fragment))
            }
        }
        return blocks
    }

    private static func body(afterFrontmatterIn source: String) -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return source
        }
        guard let end = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else {
            return source
        }
        return lines.dropFirst(end + 1).joined(separator: "\n")
    }

    private static func blockDescriptor(
        for intent: PresentationIntent
    ) -> (identity: Int, kind: BlockKind) {
        var paragraph: PresentationIntent.IntentType?
        var listItem: (identity: Int, ordinal: Int)?
        var unordered = false

        for component in intent.components {
            switch component.kind {
            case .header(let level):
                return (component.identity, .heading(level: level))
            case .codeBlock(let language):
                return (component.identity, .codeBlock(language: language))
            case .paragraph:
                paragraph = component
            case .listItem(let ordinal):
                listItem = (component.identity, ordinal)
            case .unorderedList:
                unordered = true
            default:
                continue
            }
        }
        if let listItem {
            return (
                listItem.identity,
                unordered ? .unorderedListItem : .orderedListItem(ordinal: listItem.ordinal)
            )
        }
        return (paragraph?.identity ?? 0, .paragraph)
    }
}
