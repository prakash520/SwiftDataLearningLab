import Foundation
import SwiftData

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case unread
    case reading
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unread: "Unread"
        case .reading: "Reading"
        case .finished: "Finished"
        }
    }
}

/// Composite value stored with the model. SwiftData encodes it as a transformable
/// attribute. Its fields are not separate columns, so predicates cannot filter
/// `metadata.rating` the way they can filter `name`.
struct ItemMetadata: Codable, Hashable, Sendable {
    var source: String
    var rating: Int
}

@Model
final class DesignedItem {
    /// One stored row per value. A later save with the same SKU replaces that
    /// row on this SDK. It does not throw. Refuse a duplicate before insert.
    @Attribute(.unique) var sku: String

    var name: String
    var nickname: String?
    var quantity: Int
    var price: Double
    var isArchived: Bool
    var addedOn: Date
    var identifier: UUID
    var externalLink: URL?
    var thumbnail: Data?
    var status: ReadingStatus
    var tags: [String]
    var metadata: ItemMetadata

    /// Lives on the instance for this process only. It is not a column.
    @Transient var draftNote: String = ""

    /// Computed values are not columns and cannot appear in `#Predicate`.
    var displayName: String {
        nickname ?? name
    }

    init(
        sku: String,
        name: String,
        nickname: String? = nil,
        quantity: Int = 1,
        price: Double = 0,
        isArchived: Bool = false,
        addedOn: Date = .now,
        identifier: UUID = UUID(),
        externalLink: URL? = nil,
        thumbnail: Data? = nil,
        status: ReadingStatus = .unread,
        tags: [String] = [],
        metadata: ItemMetadata = ItemMetadata(source: "Lab", rating: 0)
    ) {
        self.sku = sku
        self.name = name
        self.nickname = nickname
        self.quantity = quantity
        self.price = price
        self.isArchived = isArchived
        self.addedOn = addedOn
        self.identifier = identifier
        self.externalLink = externalLink
        self.thumbnail = thumbnail
        self.status = status
        self.tags = tags
        self.metadata = metadata
    }
}
