import SwiftUI
import SwiftData
import MapKit

struct SiteListView: View {
    @State private var query = ""
    @State private var mapMode = false
    @State private var types: Set<String> = []
    @State private var countries: Set<String> = []
    @State private var selected: Site?
    private let catalog = Catalog.shared

    var filtered: [Site] {
        catalog.searchSites(query).filter { (types.isEmpty || !types.isDisjoint(with: $0.types)) && (countries.isEmpty || countries.contains($0.country)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("视图", selection: $mapMode) {
                    Label("列表", systemImage: "list.bullet").tag(false)
                    Label("地图", systemImage: "map").tag(true)
                }.pickerStyle(.segmented)
                chips(catalog.countries, $countries)
                chips(catalog.siteTypes, $types)
                if filtered.isEmpty {
                    EmptyState(symbol: "line.3.horizontal.decrease.circle", title: "没有符合条件的潜点", button: "清除筛选") { types = []; countries = []; query = "" }
                } else if mapMode {
                    mapView
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filtered) { s in
                            NavigationLink(value: Route.site(s.id)) {
                                let n = catalog.species(at: s.id).count
                                SitePhotoCard(site: s, height: s.isCurated ? 220 : 120)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text(s.isCurated ? "代表生物 \(n) 种" : (n > 0 ? "观测记录 \(n) 种" : "暂无物种记录")).font(.caption).foregroundStyle(.white).padding(16)
                                    }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin).padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("潜点")
        .searchable(text: $query, prompt: "搜索国家、地区或潜点名")
    }

    private func chips(_ items: [String], _ sel: Binding<Set<String>>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Chip(text: "全部", selected: sel.wrappedValue.isEmpty) { sel.wrappedValue = [] }
                ForEach(items, id: \.self) { t in
                    Chip(text: t, selected: sel.wrappedValue.contains(t)) {
                        if sel.wrappedValue.contains(t) { sel.wrappedValue.remove(t) } else { sel.wrappedValue.insert(t) }
                    }
                }
            }
        }
    }

    private var mapView: some View {
        VStack(spacing: 12) {
            Map(selection: Binding(get: { selected?.id }, set: { id in selected = filtered.first { $0.id == id } })) {
                ForEach(filtered) { s in
                    Marker(s.name, coordinate: .init(latitude: s.lat, longitude: s.lon)).tint(Theme.accent).tag(s.id)
                }
            }
            .frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 20))
            if let s = selected {
                NavigationLink(value: Route.site(s.id)) {
                    HStack {
                        VStack(alignment: .leading) { Text(s.name).font(.headline); Text(s.place).font(.caption).foregroundStyle(Theme.inkSecondary) }
                        Spacer(); Text("查看详情").font(.subheadline); Image(systemName: "chevron.right")
                    }
                    .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct SiteDetailView: View {
    let siteID: String
    @Environment(\.startLog) private var startLog
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    private let catalog = Catalog.shared

    var body: some View {
        if let site = catalog.site(siteID) {
            let siteLogs = logs.filter { $0.siteID == siteID }
            let spList = catalog.species(at: siteID)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ZStack(alignment: .bottomTrailing) {
                        BundledImage(name: site.image).frame(maxWidth: .infinity).aspectRatio(site.isCurated ? 4/3 : 16/9, contentMode: .fit).clipped()
                        if let c = catalog.credit(site.image) {
                            Text("照片：\(c.author) / \(c.license)").font(.caption2).padding(6).background(.ultraThinMaterial, in: Capsule()).padding(8)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(site.isCurated ? site.nameZh : site.name).font(.display).foregroundStyle(Theme.ink)
                        Text(site.isCurated ? "\(site.name) · \(site.place)" : site.place).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        if let d = site.depth { Text("最大深度约 \(d) 米").font(.subheadline).foregroundStyle(Theme.inkSecondary) }
                        HStack { ForEach(site.types, id: \.self) { TagText(text: $0) } }
                    }.padding(.horizontal, Theme.margin)
                    if site.isCurated {
                        section("简介") { Text(site.summary).foregroundStyle(Theme.ink) }
                        section("潜水环境") { BulletList(items: site.characteristics) }
                    }
                    if spList.isEmpty {
                        let reg = catalog.regionalSpecies(at: siteID)
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "物种", subtitle: nil).padding(.horizontal, Theme.margin)
                            if reg.isEmpty {
                                Text("暂无物种记录").foregroundStyle(Theme.inkSecondary).padding(.horizontal, Theme.margin)
                            } else {
                                Text("这个点附近暂无公开的观测记录。下面是\(site.country)其他潜点的常见观测物种，不代表这个点一定能看到。").font(.footnote).foregroundStyle(Theme.inkSecondary).padding(.horizontal, Theme.margin)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(alignment: .top, spacing: 12) {
                                        ForEach(reg, id: \.0.id) { sp, link in
                                            NavigationLink(value: Route.species(sp.id)) {
                                                VStack(alignment: .leading, spacing: 4) { SpeciesCard(species: sp); TagText(text: link.evidenceLabel) }
                                            }.buttonStyle(.plain)
                                        }
                                    }.padding(.horizontal, Theme.margin)
                                }
                            }
                        }
                    } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: site.isCurated ? "可能遇见的生物" : "观测记录里的物种", subtitle: "共 \(spList.count) 种").padding(.horizontal, Theme.margin)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(spList, id: \.0.id) { sp, link in
                                    NavigationLink(value: Route.species(sp.id)) {
                                        VStack(alignment: .leading, spacing: 4) { SpeciesCard(species: sp); TagText(text: link.evidenceLabel) }
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, Theme.margin)
                        }
                        NavigationLink(value: Route.library(siteID: siteID)) { Text("查看全部 \(spList.count) 种").font(.subheadline).frame(minHeight: 44) }
                            .padding(.horizontal, Theme.margin)
                        Text(site.isCurated ? "生物清单来自公开资料，仅供参考，实际遇见情况因季节与天气而异。" : "来自公开的观测记录（GBIF，CC0 或 CC BY），只代表这个点 2 公里内有人记录过，不代表一定能遇见。").font(.caption).foregroundStyle(Theme.inkSecondary).padding(.horizontal, Theme.margin)
                    }
                    }
                    if let c = site.credit { Text("潜点数据：\(c)").font(.caption).foregroundStyle(Theme.inkSecondary).padding(.horizontal, Theme.margin) }
                    section("我在这里的日志") {
                        if siteLogs.isEmpty {
                            EmptyState(symbol: "book.closed", title: "还没有在这里的日志", button: "写一篇日志") { startLog(siteID) }
                        } else {
                            VStack(spacing: 12) { ForEach(siteLogs) { l in NavigationLink(value: Route.log(l.id)) { LogCard(log: l) }.buttonStyle(.plain) } }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    FavoriteButton(type: "site", id: siteID, label: site.name)
                    ShareLink(item: "\(site.name) · \(site.place)") { Image(systemName: "square.and.arrow.up") }
                }
            }
        } else {
            EmptyState(symbol: "exclamationmark.triangle", title: "内容没有加载出来")
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            content()
        }.padding(.horizontal, Theme.margin)
    }
}
