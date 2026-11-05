import SwiftUI
import SwiftData

enum Route: Hashable {
    case site(String)
    case species(String)
    case sites
    case library(siteID: String?)
    case log(UUID)
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .site(let id): SiteDetailView(siteID: id)
            case .species(let id): SpeciesDetailView(speciesID: id)
            case .sites: SiteListView()
            case .library(let sid): LibraryView(siteID: sid)
            case .log(let id): LogDetailView(logID: id)
            }
        }
    }
}

struct ExploreView: View {
    @Environment(\.startLog) private var startLog
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var showIdentify = false
    private let catalog = Catalog.shared

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty { home } else { results }
            }
            .screenBackground()
            .navigationTitle("Dive into ocean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(query.isEmpty ? .hidden : .automatic, for: .navigationBar)
            .searchable(text: $query, prompt: "搜索潜点、物种或学名")
            .routes()
            .fullScreenCover(isPresented: $showIdentify) { IdentifyView() }
        }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                identifyCard.padding(.horizontal, Theme.margin).offset(y: -28).padding(.bottom, -28)
                VStack(alignment: .leading, spacing: 32) {
                    if catalog.sites.isEmpty { ErrorBanner(title: "内容没有加载出来") }
                    daily
                    sitesRail
                    speciesRail
                }
                .padding(.top, 32).padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            BundledImage(name: "hero").frame(maxWidth: .infinity).frame(height: 420).clipped()
            Scrim()
            VStack(alignment: .leading, spacing: 8) {
                Text("DIVE INTO OCEAN").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.8))
                Text("Explore the ocean.").font(.display).foregroundStyle(.white)
                Text("今天想看见什么？").font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, Theme.margin).padding(.bottom, 52)
        }
        .frame(height: 420)
        .accessibilityLabel("海龟在珊瑚礁上方游动")
    }

    private var identifyCard: some View {
        Button { showIdentify = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder").font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44).background(Theme.tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    VStack(alignment: .leading, spacing: 4) { Text("认一认这张照片").font(.headline).fixedSize(horizontal: false, vertical: true); DemoBadge().fixedSize() }
                    Text("上传水下照片，看看可能是哪种生物").font(.caption).foregroundStyle(Theme.inkSecondary).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSecondary)
            }
            .padding(14).frame(minHeight: 72)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("identify-entry")
    }

    @ViewBuilder private var daily: some View {
        if let d = catalog.today {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "每日海洋发现", subtitle: "\(Calendar.current.component(.month, from: .now))月\(Calendar.current.component(.day, from: .now))日", action: "了解更多") { path.append(Route.species(d.speciesID)) }
                Button { path.append(Route.species(d.speciesID)) } label: {
                    ZStack(alignment: .bottomLeading) {
                        BundledImage(name: d.image).frame(maxWidth: .infinity).frame(height: 220).clipped()
                        Scrim()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.title).font(.headline).foregroundStyle(.white)
                            Text(d.fact).font(.subheadline).foregroundStyle(.white.opacity(0.9)).lineLimit(3).multilineTextAlignment(.leading)
                        }.padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(alignment: .topLeading) {
                        Text("今日发现").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule()).padding(12)
                    }
                }
                .buttonStyle(.plain)
                Text("内容为编辑精选，每天一条。").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            .padding(.horizontal, Theme.margin)
        }
    }

    private var sitesRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "热门潜点", subtitle: "Dive Sites", action: "全部") { path.append(Route.sites) }.padding(.horizontal, Theme.margin)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(catalog.sites.filter(\.isCurated)) { s in
                        Button { path.append(Route.site(s.id)) } label: { SitePhotoCard(site: s, width: 240, height: 320) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(s.name)，\(s.place)")
                    }
                }.padding(.horizontal, Theme.margin)
            }
        }
    }

    private var speciesRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "海洋生物", subtitle: "Marine Life", action: "全部") { path.append(Route.library(siteID: nil)) }.padding(.horizontal, Theme.margin)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(catalog.species.filter(\.curated).prefix(10)) { sp in
                        Button { path.append(Route.species(sp.id)) } label: { SpeciesCard(species: sp) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, Theme.margin)
            }
        }
    }

    private var results: some View {
        let sites = catalog.searchSites(query), sp = catalog.searchSpecies(query)
        return List {
            if sites.isEmpty && sp.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: "没有找到相关内容", message: "换个关键词，或试试中文名、英文名、学名")
                    .listRowBackground(Color.clear)
            }
            if !sites.isEmpty {
                Section("潜点") {
                    ForEach(sites) { s in
                        NavigationLink(value: Route.site(s.id)) {
                            VStack(alignment: .leading) { Text("\(s.nameZh) \(s.name)").font(.headline); Text(s.place).font(.caption).foregroundStyle(Theme.inkSecondary) }.frame(minHeight: 44)
                        }
                    }
                }
            }
            if !sp.isEmpty {
                Section("物种") { ForEach(sp) { s in NavigationLink(value: Route.species(s.id)) { SpeciesRow(species: s) } } }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
