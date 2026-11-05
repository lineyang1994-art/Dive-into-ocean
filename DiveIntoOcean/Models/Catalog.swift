import Foundation
import UIKit
import SwiftUI

enum SpeciesCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case reefFish, fish, sharksRays, turtles, nudibranchs, cephalopods, crustaceans, corals, other
    var zh: String {
        switch self {
        case .reefFish: "珊瑚礁鱼类"
        case .fish: "鱼类"
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
        case .fish: "Fish"
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
    var depth: Int? = nil
    var credit: String? = nil
    private enum CodingKeys: String, CodingKey { case id, name, nameZh, country, region, lat, lon, types, summary, characteristics, image }
    var place: String { region.isEmpty ? country : "\(country) · \(region)" }
    var isCurated: Bool { credit == nil }
    var display: String { nameZh == name ? name : "\(nameZh) \(name)" }
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
    var curated: Bool = true
    private enum CodingKeys: String, CodingKey { case id, nameZh, nameEn, scientific, category, family, summary, features, similar, habitat, diet, behavior, distribution, fact, tips, image, sources }
}

struct SiteSpeciesLink: Codable, Hashable, Sendable {
    let siteID: String
    let speciesID: String
    let evidence: String
    var count: Int? = nil
    var regional: Bool = false
    private enum CodingKeys: String, CodingKey { case siteID, speciesID, evidence }
    var evidenceLabel: String {
        if regional { return "区域观测，非本点" }
        if evidence == "observed" { return "观测记录 \(count ?? 0) 条" }
        return evidence == "common" ? "较常见" : "可能遇见"
    }
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

private struct ExtraData: Decodable {
    struct S: Decodable { let id, name, country: String; let lat, lon: Double; let depth: Int?; let src: String }
    struct Sp: Decodable { let id, sci, en, family, cat, image: String }
    struct Link: Decodable { let sp: LinkKey; let n: Int
        init(from d: Decoder) throws { var c = try d.unkeyedContainer(); sp = try c.decode(LinkKey.self); n = try c.decode(Int.self) } }
    enum LinkKey: Decodable { case idx(Int), old(String)
        init(from d: Decoder) throws { let c = try d.singleValueContainer(); if let i = try? c.decode(Int.self) { self = .idx(i) } else { self = .old(try c.decode(String.self)) } } }
    let sites: [S]; let species: [Sp]; let links: [[Link]]; let credits: [ImageCredit]
}

/// Local seed repository. Everything is bundled; nothing is loaded over the network.
struct Catalog: Sendable {
    static let shared = Catalog.load()
    let data: CatalogData
    let sites: [Site]
    let species: [Species]
    private let siteByID: [String: Site]
    private let speciesByID: [String: Species]
    private let linksBySite: [String: [SiteSpeciesLink]]
    private let linksBySpecies: [String: [SiteSpeciesLink]]
    private let creditByImage: [String: ImageCredit]
    let regionalBySite: [String: [SiteSpeciesLink]]
    let allCredits: [ImageCredit]

    init(data: CatalogData, extra: Data?) {
        var sites = data.sites, species = data.species, links = data.links, credits = data.credits
        var regionalBy: [String: [SiteSpeciesLink]] = [:]
        if let extra, let e = try? JSONDecoder().decode(ExtraData.self, from: extra) {
            let base = species.count
            let ids = e.species.map { $0.id }
            for sp in e.species {
                let cat = SpeciesCategory(rawValue: sp.cat) ?? .other
                let zh = sp.en.isEmpty ? sp.sci : sp.en
                species.append(Species(id: sp.id, nameZh: zh, nameEn: sp.en, scientific: sp.sci, category: cat, family: sp.family, summary: "资料待补充", features: [], similar: "", habitat: "", diet: "", behavior: "", distribution: "", fact: "", tips: [], image: sp.image, sources: "GBIF 观测记录、WoRMS", curated: false))
            }
            _ = base
            var countryCount: [String: [String: Int]] = [:]
            var noRecord: [Site] = []
            for (i, s) in e.sites.enumerated() {
                let src = s.src == "odm" ? "© OpenDiveMap contributors（ODbL）" : "© OpenStreetMap contributors（ODbL）"
                let site = Site(id: s.id, name: s.name, nameZh: s.name, country: s.country, region: "", lat: s.lat, lon: s.lon, types: [], summary: "", characteristics: [], image: "", depth: s.depth, credit: src)
                sites.append(site)
                let row = e.links[i]
                if row.isEmpty { noRecord.append(site) }
                for l in row {
                    let spID: String
                    switch l.sp { case .idx(let k): spID = ids[k]; case .old(let o): spID = o }
                    var link = SiteSpeciesLink(siteID: s.id, speciesID: spID, evidence: "observed")
                    link.count = l.n
                    links.append(link)
                    countryCount[s.country, default: [:]][spID, default: 0] += 1
                }
            }
            for s in noRecord {
                let top = (countryCount[s.country] ?? [:]).sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(12)
                regionalBy[s.id] = top.map { var l = SiteSpeciesLink(siteID: s.id, speciesID: $0.key, evidence: "regional"); l.regional = true; return l }
            }
            credits += e.credits
        }
        self.data = CatalogData(sites: sites, species: species, links: links, daily: data.daily, credits: credits)
        self.sites = sites; self.species = species
        self.siteByID = Dictionary(sites.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.speciesByID = Dictionary(species.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.linksBySite = Dictionary(grouping: links, by: \.siteID).mapValues { $0.sorted { ($0.count ?? 0) > ($1.count ?? 0) } }
        self.linksBySpecies = Dictionary(grouping: links, by: \.speciesID).mapValues { $0.sorted { ($0.count ?? 0) > ($1.count ?? 0) } }
        self.creditByImage = Dictionary(credits.map { ($0.image, $0) }, uniquingKeysWith: { a, _ in a })
        self.regionalBySite = regionalBy
        self.allCredits = credits
    }

    static func load() -> Catalog {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(CatalogData.self, from: d) else {
            return Catalog(data: CatalogData(sites: [], species: [], links: [], daily: [], credits: []), extra: nil)
        }
        let extra = Bundle.main.url(forResource: "extra", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        return Catalog(data: c, extra: extra)
    }
    func site(_ id: String) -> Site? { siteByID[id] }
    func species(_ id: String) -> Species? { speciesByID[id] }
    /// Species with a record at this site (not regional).
    func species(at siteID: String) -> [(Species, SiteSpeciesLink)] {
        (linksBySite[siteID] ?? []).compactMap { l in species(l.speciesID).map { ($0, l) } }
    }
    func regionalSpecies(at siteID: String) -> [(Species, SiteSpeciesLink)] {
        (regionalBySite[siteID] ?? []).compactMap { l in species(l.speciesID).map { ($0, l) } }
    }
    func sites(for speciesID: String) -> [(Site, SiteSpeciesLink)] {
        (linksBySpecies[speciesID] ?? []).prefix(30).compactMap { l in site(l.siteID).map { ($0, l) } }
    }
    func credit(_ image: String) -> ImageCredit? { creditByImage[image] }
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
