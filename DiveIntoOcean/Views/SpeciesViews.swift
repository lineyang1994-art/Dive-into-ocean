import SwiftUI
import SwiftData

struct LibraryView: View {
    var siteID: String? = nil
    @State private var query = ""
    @State private var category: SpeciesCategory? = nil
    @State private var listMode = false
    @State private var filter = 0 // 0 all 1 favorites 2 seen
    @Query private var favs: [FavoriteItem]
    @Query private var sightings: [Sighting]
    @Environment(\.dynamicTypeSize) private var dts
    private let catalog = Catalog.shared

    var items: [Species] {
        let base = siteID.map { sid in catalog.species(at: sid).map(\.0) } ?? catalog.species
        let favIDs = Set(favs.filter { $0.targetType == "species" }.map(\.targetID))
        let seenIDs = Set(sightings.filter { $0.log != nil }.map(\.speciesID))
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return base.filter { s in
            (category == nil || s.category == category) &&
            (filter == 0 || (filter == 1 && favIDs.contains(s.id)) || (filter == 2 && seenIDs.contains(s.id))) &&
            (q.isEmpty || s.nameZh.lowercased().contains(q) || s.nameEn.lowercased().contains(q) || s.scientific.lowercased().contains(q))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Chip(text: "全部", selected: category == nil) { category = nil }
                        ForEach(SpeciesCategory.allCases, id: \.self) { c in
                            Chip(text: c.zh, selected: category == c) { category = c }
                        }
                    }
                }
                if items.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: query.isEmpty ? "没有符合条件的物种" : "没有找到「\(query)」", message: "试试中文名、英文名或学名。", button: "清除筛选") { query = ""; category = nil; filter = 0 }
                } else if listMode {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { s in
                            NavigationLink(value: Route.species(s.id)) { SpeciesRow(species: s) }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dts.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(items) { s in
                            NavigationLink(value: Route.species(s.id)) {
                                ZStack(alignment: .bottomLeading) {
                                    BundledImage(name: s.image).aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped()
                                    Scrim()
                                    VStack(alignment: .leading) {
                                        Text(s.nameZh).font(.headline).foregroundStyle(.white).lineLimit(2)
                                        Text(s.scientific).font(.caption.italic()).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                                    }.padding(12)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(alignment: .topTrailing) { FavoriteButton(type: "species", id: s.id, label: s.nameZh).padding(8) }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin).padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(siteID.flatMap { catalog.site($0)?.nameZh } ?? "图鉴")
        .searchable(text: $query, prompt: "搜索中文名、英文名或学名")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { listMode.toggle() } label: { Image(systemName: listMode ? "square.grid.2x2" : "list.bullet") }
                    .accessibilityLabel(listMode ? "网格" : "列表")
                Menu {
                    Picker("筛选", selection: $filter) { Text("全部").tag(0); Text("已收藏").tag(1); Text("已发现").tag(2) }
                } label: { Image(systemName: filter == 0 ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill") }
            }
        }
    }
}

struct SpeciesDetailView: View {
    let speciesID: String
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    @Query private var sightings: [Sighting]
    @Environment(\.modelContext) private var context
    @Environment(\.startLog) private var startLog
    @State private var showPicker = false
    @State private var toast: String?
    private let catalog = Catalog.shared

    var body: some View {
        if let sp = catalog.species(speciesID) {
            let mine = sightings.filter { $0.speciesID == speciesID && $0.log != nil }
            let mineLogs = Array(Set(mine.compactMap { $0.log?.id })).compactMap { id in logs.first { $0.id == id } }.sorted { $0.date > $1.date }
            let seen = !mine.isEmpty
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ZStack(alignment: .bottomTrailing) {
                        BundledImage(name: sp.image).frame(maxWidth: .infinity).aspectRatio(4/3, contentMode: .fit).clipped()
                        if let c = catalog.credit(sp.image) {
                            Text("照片：\(c.author) / \(c.license)").font(.caption2).padding(6).background(.ultraThinMaterial, in: Capsule()).padding(8)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sp.nameZh).font(.display).foregroundStyle(Theme.ink)
                        if sp.nameEn != sp.nameZh { Text(sp.nameEn).font(.subheadline).foregroundStyle(Theme.ink) }
                        Text(sp.scientific).font(.subheadline.italic()).foregroundStyle(Theme.inkSecondary)
                        HStack { TagText(text: sp.category.zh); Text(sp.family).font(.caption).foregroundStyle(Theme.inkSecondary) }.padding(.top, 4)
                        Text(sp.summary).foregroundStyle(sp.curated ? Theme.ink : Theme.inkSecondary).padding(.top, 6)
                    }.padding(.horizontal, Theme.margin)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SpeciesFavoriteBar(speciesID: sp.id, name: sp.nameZh)
                            Button { showPicker = true } label: {
                                Label(seen ? "再次记录" : "标记为见过", systemImage: seen ? "checkmark.seal.fill" : "checkmark.seal").frame(maxWidth: .infinity, minHeight: 48)
                            }.buttonStyle(.borderedProminent)
                        }
                        Text("记录你亲眼见过它。收藏不会算作发现。").font(.caption).foregroundStyle(Theme.inkSecondary)
                        if seen {
                            Label("亲眼发现 · \(mine.map { $0.log!.date }.min()!.formatted(dateFormat))", systemImage: "checkmark.seal.fill")
                                .font(.subheadline).foregroundStyle(Theme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.tint, in: Capsule())
                        }
                    }.padding(.horizontal, Theme.margin)

                    if !sp.curated {
                        block("资料") { Text("识别特征、生态知识和观察提示：资料待补充。").foregroundStyle(Theme.inkSecondary) }
                    }
                    if sp.curated {
                    block("识别特征") {
                        BulletList(items: sp.features)
                        CalloutCard(symbol: "arrow.left.arrow.right", title: "与相似物种的区别", text: sp.similar).padding(.top, 8)
                    }
                    block("生态知识") {
                        kv("栖息环境", sp.habitat); kv("食性", sp.diet); kv("典型行为", sp.behavior); kv("分布", sp.distribution)
                        CalloutCard(symbol: "lightbulb", title: "有趣的事", text: sp.fact)
                    }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("潜水观察").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink).padding(.horizontal, Theme.margin)
                        Text("可能遇见的潜点").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSecondary).padding(.horizontal, Theme.margin)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(catalog.sites(for: sp.id), id: \.0.id) { s, link in
                                    NavigationLink(value: Route.site(s.id)) {
                                        ZStack(alignment: .bottomLeading) {
                                            BundledImage(name: s.image).frame(width: 200, height: 140).clipped(); Scrim()
                                            VStack(alignment: .leading) { Text(s.isCurated ? s.nameZh : s.name).font(.headline).lineLimit(2); Text(link.evidenceLabel).font(.caption) }.foregroundStyle(.white).padding(12)
                                        }.frame(width: 200, height: 140).clipShape(RoundedRectangle(cornerRadius: 16))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, Theme.margin)
                        }
                        if sp.curated {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("观察提示").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                            BulletList(items: sp.tips, symbol: "exclamationmark.circle")
                        }.padding(.horizontal, Theme.margin)
                        }
                    }
                    block("记录过它的日志") {
                        if mineLogs.isEmpty { Text("还没有日志记录过它").foregroundStyle(Theme.inkSecondary) }
                        else { VStack(spacing: 12) { ForEach(mineLogs) { l in NavigationLink(value: Route.log(l.id)) { LogCard(log: l) }.buttonStyle(.plain) } } }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("资料来源：\(sp.sources)").font(.caption).foregroundStyle(Theme.inkSecondary)
                        if let c = catalog.credit(sp.image) {
                            Link("照片：\(c.author) / \(c.license)，来自 Wikimedia Commons", destination: URL(string: c.source)!).font(.caption)
                        }
                    }.padding(.horizontal, Theme.margin)
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ShareLink(item: "\(sp.nameZh) \(sp.nameEn) (\(sp.scientific))") { Image(systemName: "square.and.arrow.up") } } }
            .toast($toast)
            .sheet(isPresented: $showPicker) {
                MarkSeenSheet(species: sp) { toast = $0 }
            }
        } else {
            EmptyState(symbol: "exclamationmark.triangle", title: "内容没有加载出来")
        }
    }

    private func block<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            content()
        }.padding(.horizontal, Theme.margin)
    }
    private func kv(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).foregroundStyle(Theme.inkSecondary)
            Text(v).foregroundStyle(Theme.ink)
        }
    }
}

struct SpeciesFavoriteBar: View {
    let speciesID: String
    let name: String
    @Environment(\.modelContext) private var context
    @Query private var favs: [FavoriteItem]
    init(speciesID: String, name: String) {
        self.speciesID = speciesID; self.name = name
        _favs = Query(filter: #Predicate<FavoriteItem> { $0.targetType == "species" && $0.targetID == speciesID })
    }
    var body: some View {
        let on = !favs.isEmpty
        Button {
            if let f = favs.first { context.delete(f) } else { context.insert(FavoriteItem(type: "species", id: speciesID)) }
            try? context.save()
        } label: {
            Label(on ? "已收藏" : "收藏", systemImage: on ? "heart.fill" : "heart").frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(on ? Theme.favorite : Theme.accent)
        }
        .buttonStyle(.bordered)
        .sensoryFeedback(.success, trigger: on)
        .accessibilityLabel(on ? "取消收藏 \(name)" : "收藏 \(name)")
    }
}

/// A discovery must belong to a log. Pick an existing one or create a new one with this species.
struct MarkSeenSheet: View {
    let species: Species
    var done: (String) -> Void
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    private let catalog = Catalog.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { creating = true } label: { Label("新建日志并添加", systemImage: "plus.circle") }
                } footer: { Text("发现必须属于一篇日志。收藏不会算作发现。") }
                if !logs.isEmpty {
                    Section("添加到现有日志") {
                        ForEach(logs) { l in
                            let already = l.sightings.contains { $0.speciesID == species.id }
                            Button {
                                if !already { l.sightings.append(Sighting(speciesID: species.id, status: .manual)); try? context.save() }
                                done("已添加到日志"); dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(catalog.site(l.siteID)?.nameZh ?? "—").foregroundStyle(Theme.ink)
                                        Text(l.date.formatted(dateFormat)).font(.caption).foregroundStyle(Theme.inkSecondary)
                                    }
                                    Spacer()
                                    if already { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标记为见过").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .sheet(isPresented: $creating) {
                LogEditorView(presetSite: nil, presetSpecies: [species.id]) { _ in done("已保存"); dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
