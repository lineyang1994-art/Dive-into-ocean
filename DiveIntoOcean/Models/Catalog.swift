import Foundation
import UIKit
import SwiftUI

enum SpeciesCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case reefFish, sharksRays, turtles, nudibranchs, cephalopods, crustaceans, corals, other
    var zh: String {
        switch self {
        case .reefFish: "珊瑚礁鱼类"
        case .sharksRays: "鲨鱼与鳐鱼"
        case .turtles: "海龟"
        case .nudibranchs: "海蛞蝓"
        case .cephalopods: "头足类"
        case .crustaceans: "甲壳类"
        case .corals: "珊瑚"
        case .other: "其他海洋生物"
        }
    }
    var en: String {
        switch self {
        case .reefFish: "Reef Fish"
        case .sharksRays: "Sharks & Rays"
        case .turtles: "Sea Turtles"
        case .nudibranchs: "Nudibranchs"
        case .cephalopods: "Cephalopods"
        case .crustaceans: "Crustaceans"
        case .corals: "Corals"
        case .other: "Other Marine Life"
        }
    }
}

struct Site: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let nameZh: String
    let country: String
    let region: String
    let lat: Double
    let lon: Double
    let types: [String]
    let summary: String
    let characteristics: [String]
    let image: String
    var place: String { "\(country) · \(region)" }
}

struct Species: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let nameZh: String
    let nameEn: String
    let scientific: String
    let category: SpeciesCategory
    let family: String
    let summary: String
    let features: [String]
    let similar: String
    let habitat: String
    let diet: String
    let behavior: String
    let distribution: String
    let fact: String
    let tips: [String]
    let image: String
    let sources: String
}

struct SiteSpeciesLink: Codable, Hashable, Sendable {
    let siteID: String
    let speciesID: String
    let evidence: String
    var evidenceLabel: String { evidence == "common" ? "较常见" : "可能遇见" }
}

struct DailyDiscovery: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let fact: String
    let speciesID: String
    let image: String
}

struct ImageCredit: Codable, Hashable, Sendable {
    let image: String
    let author: String
    let license: String
    let source: String
}

struct CatalogData: Codable, Sendable {
    let sites: [Site]
    let species: [Species]
    let links: [SiteSpeciesLink]
    let daily: [DailyDiscovery]
    let credits: [ImageCredit]
}

/// Local seed repository. Replace with a remote implementation later.
struct Catalog: Sendable {
    static let shared = Catalog.load()
    let data: CatalogData
    var sites: [Site] { data.sites }
    var species: [Species] { data.species }

    static func load() -> Catalog {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(CatalogData.self, from: d) else {
            return Catalog(data: CatalogData(sites: [], species: [], links: [], daily: [], credits: []))
        }
        return Catalog(data: c)
    }
    func site(_ id: String) -> Site? { data.sites.first { $0.id == id } }
    func species(_ id: String) -> Species? { data.species.first { $0.id == id } }
    func species(at siteID: String) -> [(Species, SiteSpeciesLink)] {
        data.links.filter { $0.siteID == siteID }.compactMap { l in species(l.speciesID).map { ($0, l) } }
    }
    func sites(for speciesID: String) -> [(Site, SiteSpeciesLink)] {
        data.links.filter { $0.speciesID == speciesID }.compactMap { l in site(l.siteID).map { ($0, l) } }
    }
    func credit(_ image: String) -> ImageCredit? { data.credits.first { $0.image == image } }
    var today: DailyDiscovery? {
        guard !data.daily.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return data.daily[day % data.daily.count]
    }
    var siteTypes: [String] {
        var seen: [String] = []
        for s in data.sites { for t in s.types where !seen.contains(t) { seen.append(t) } }
        return seen
    }
    var countries: [String] {
        var seen: [String] = []
        for s in data.sites where !seen.contains(s.country) { seen.append(s.country) }
        return seen
    }
    func searchSpecies(_ q: String) -> [Species] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return data.species }
        return data.species.filter {
            $0.nameZh.lowercased().contains(t) || $0.nameEn.lowercased().contains(t) || $0.scientific.lowercased().contains(t)
        }
    }
    func searchSites(_ q: String) -> [Site] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return data.sites }
        return data.sites.filter {
            $0.name.lowercased().contains(t) || $0.nameZh.contains(t) || $0.country.lowercased().contains(t) || $0.region.lowercased().contains(t)
        }
    }
}

@MainActor
enum ImageStore {
    private static let cache = NSCache<NSString, UIImage>()
    static func bundled(_ name: String) -> UIImage? {
        if let i = cache.object(forKey: name as NSString) { return i }
        guard let path = Bundle.main.path(forResource: name, ofType: "jpg"), let img = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }
    static var photosDir: URL {
        let d = URL.documentsDirectory.appending(path: "photos")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func savePhoto(_ data: Data) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let r = UIGraphicsImageRenderer(size: size)
        let resized = r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpg = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do { try jpg.write(to: photosDir.appending(path: name)); return name } catch { return nil }
    }
    static func photo(_ file: String) -> UIImage? {
        if let i = cache.object(forKey: file as NSString) { return i }
        guard let img = UIImage(contentsOfFile: photosDir.appending(path: file).path) else { return nil }
        cache.setObject(img, forKey: file as NSString)
        return img
    }
    static func deletePhoto(_ file: String) { try? FileManager.default.removeItem(at: photosDir.appending(path: file)) }
}
