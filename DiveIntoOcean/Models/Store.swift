import Foundation
import SwiftData

@Model
final class DiveLogEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var siteID: String
    var maxDepth: Double
    var duration: Int
    var temperature: Double?
    var visibility: Double?
    var notes: String
    var photoFiles: [String]
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Sighting.log) var sightings: [Sighting] = []

    init(date: Date, siteID: String, maxDepth: Double, duration: Int, temperature: Double?, visibility: Double?, notes: String, photoFiles: [String]) {
        self.id = UUID(); self.date = date; self.siteID = siteID; self.maxDepth = maxDepth; self.duration = duration
        self.temperature = temperature; self.visibility = visibility; self.notes = notes; self.photoFiles = photoFiles
        self.createdAt = .now
    }
}

enum IdentificationStatus: String, Codable, Sendable {
    case manual      // 手动选择（从图鉴添加）
    case candidate   // 待确认
    case confirmed   // 已确认（用户自己确认）
    var label: String {
        switch self { case .manual: "手动选择"; case .candidate: "待确认"; case .confirmed: "已确认" }
    }
}

@Model
final class Sighting {
    @Attribute(.unique) var id: UUID
    var speciesID: String
    var statusRaw: String
    var photoFile: String?
    var log: DiveLogEntry?
    var createdAt: Date
    var status: IdentificationStatus { IdentificationStatus(rawValue: statusRaw) ?? .manual }
    init(speciesID: String, status: IdentificationStatus, photoFile: String? = nil) {
        self.id = UUID(); self.speciesID = speciesID; self.statusRaw = status.rawValue; self.photoFile = photoFile; self.createdAt = .now
    }
}

@Model
final class FavoriteItem {
    var targetType: String   // "species" | "site"
    var targetID: String
    var createdAt: Date
    init(type: String, id: String) { targetType = type; targetID = id; createdAt = .now }
}
