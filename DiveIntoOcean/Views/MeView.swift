import SwiftUI
import SwiftData
import PhotosUI

struct MeView: View {
    var goExplore: () -> Void
    @Environment(\.startLog) private var startLog
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    @Query private var favs: [FavoriteItem]
    @AppStorage("nickname") private var nickname = "海洋探索者"
    @AppStorage("avatarFile") private var avatarFile = ""
    @State private var section = 0
    @State private var favSegment = 0
    @State private var path = NavigationPath()
    private let catalog = Catalog.shared

    private var discovered: [(Species, Date, [DiveLogEntry])] {
        var map: [String: [DiveLogEntry]] = [:]
        for l in logs { for s in l.sightings { map[s.speciesID, default: []].append(l) } }
        return map.compactMap { id, ls in catalog.species(id).map { ($0, ls.map(\.date).min()!, ls) } }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Group {
                            if !avatarFile.isEmpty, ImageStore.photo(avatarFile) != nil { UserPhoto(file: avatarFile) }
                            else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(Theme.accent.opacity(0.6)).padding(0) }
                        }.frame(width: 72, height: 72).background(Theme.tint).clipShape(Circle())
                        VStack(alignment: .leading) { Text(nickname).font(.title2.bold()).foregroundStyle(Theme.ink); Text("潜水员").font(.caption).foregroundStyle(Theme.inkSecondary) }
                        Spacer()
                        NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("设置")
                    }
                    HStack(spacing: 12) {
                        StatTile(value: "\(logs.count)", label: "下潜")
                        StatTile(value: "\(Set(logs.map(\.siteID)).count)", label: "潜点")
                        StatTile(value: "\(discovered.count)", label: "物种")
                    }
                    Picker("", selection: $section) { Text("发现").tag(0); Text("收藏").tag(1); Text("足迹").tag(2) }.pickerStyle(.segmented)
                    switch section {
                    case 0: discoveries
                    case 1: favorites
                    default: history
                    }
                }
                .padding(.horizontal, Theme.margin).padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
            .routes()
        }
    }

    private var discoveries: some View {
        VStack(alignment: .leading, spacing: 10) {
            if discovered.isEmpty {
                EmptyState(symbol: "sparkles", title: "还没有发现", message: "在日志里添加你见到的生物，它们会出现在这里", button: "写一篇日志") { startLog(nil) }
            } else {
                Text("我的发现").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("你在日志中亲自记录的物种 · 已发现 \(discovered.count) 种").font(.caption).foregroundStyle(Theme.inkSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(discovered, id: \.0.id) { sp, first, _ in
                        NavigationLink(value: Route.species(sp.id)) {
                            VStack(spacing: 4) {
                                BundledImage(name: sp.image).aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped().aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(sp.nameZh).font(.caption.weight(.medium)).foregroundStyle(Theme.ink).lineLimit(2)
                                Text(first.formatted(.dateTime.month().day().locale(zhLocale))).font(.caption2).foregroundStyle(Theme.inkSecondary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var favorites: some View {
        let sp = favs.filter { $0.targetType == "species" }.sorted { $0.createdAt > $1.createdAt }.compactMap { catalog.species($0.targetID) }
        let st = favs.filter { $0.targetType == "site" }.sorted { $0.createdAt > $1.createdAt }.compactMap { catalog.site($0.targetID) }
        return VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $favSegment) { Text("物种").tag(0); Text("潜点").tag(1) }.pickerStyle(.segmented)
            Text("收藏不等于发现。").font(.caption).foregroundStyle(Theme.inkSecondary)
            if (favSegment == 0 ? sp.isEmpty : st.isEmpty) {
                EmptyState(symbol: "heart", title: "还没有收藏", message: "在探索里点收藏，方便以后查看", button: "去探索") { goExplore() }
            } else if favSegment == 0 {
                ForEach(sp) { s in NavigationLink(value: Route.species(s.id)) { SpeciesRow(species: s) }.buttonStyle(.plain) }
            } else {
                ForEach(st) { s in
                    NavigationLink(value: Route.site(s.id)) {
                        HStack(spacing: 12) {
                            BundledImage(name: s.image).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading) { Text(s.nameZh).font(.headline); Text(s.place).font(.caption).foregroundStyle(Theme.inkSecondary) }.foregroundStyle(Theme.ink)
                            Spacer()
                        }.frame(minHeight: 72)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            if logs.isEmpty { EmptyState(symbol: "book.closed", title: "还没有日志", message: "记下第一次下潜，和那天遇见的生物", button: "写第一篇日志") { startLog(nil) } }
            else {
                ForEach(logs) { l in NavigationLink(value: Route.log(l.id)) { LogCard(log: l) }.buttonStyle(.plain) }
                let photos = logs.flatMap(\.photoFiles)
                if !photos.isEmpty {
                    Text("我的照片").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(photos, id: \.self) { UserPhoto(file: $0).aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped().aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("nickname") private var nickname = "海洋探索者"
    @AppStorage("avatarFile") private var avatarFile = ""
    @AppStorage("appearance") private var appearance = 0
    @Environment(\.modelContext) private var context
    @State private var confirmClear = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var cleared = false
    var body: some View {
        List {
            Section("编辑资料") {
                TextField("给自己起个名字", text: $nickname).accessibilityIdentifier("nickname-field")
                PhotosPicker(selection: $avatarItem, matching: .images) { Label("头像", systemImage: "person.crop.circle") }
            }
            Section("外观") {
                Picker("外观", selection: $appearance) { Text("跟随系统").tag(0); Text("浅色").tag(1); Text("深色").tag(2) }
            }
            Section("关于") {
                Text("Dive into ocean 是帮你认识海洋生物、记录每次下潜的小应用。").font(.subheadline)
                Text("识别功能目前为演示模式，结果为模拟内容。").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
            Section("数据与隐私") {
                Text("你的资料、日志和照片只保存在这台设备上，不需要账号。").font(.subheadline)
                Button("清除我的数据", role: .destructive) { confirmClear = true }
            }
            Section { NavigationLink("图片来源") { CreditsView() } }
            Section { MadeWithAirBuild() }
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .onChange(of: avatarItem) { _, new in
            Task { if let new, let d = try? await new.loadTransferable(type: Data.self), let f = ImageStore.savePhoto(d) { avatarFile = f } }
        }
        .confirmationDialog("清除所有日志、收藏和发现？无法恢复", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除", role: .destructive) {
                try? context.delete(model: DiveLogEntry.self); try? context.delete(model: Sighting.self); try? context.delete(model: FavoriteItem.self)
                try? context.save()
                if let files = try? FileManager.default.contentsOfDirectory(atPath: ImageStore.photosDir.path) { files.forEach(ImageStore.deletePhoto) }
                avatarFile = ""; nickname = "海洋探索者"
            }
            Button("取消", role: .cancel) {}
        }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section { Text("图鉴与潜点照片来自 Wikimedia Commons，按各自的许可使用").font(.subheadline) }
            Section("数据来源与许可") {
                Text("潜点：© OpenDiveMap contributors（ODbL）；© OpenStreetMap contributors（ODbL）").font(.caption)
                Text("物种观测记录：GBIF，只使用 CC0 或 CC BY 许可的记录").font(.caption)
                Text("学名核对：WoRMS（CC BY 4.0）").font(.caption)
            }
            Section {
                ForEach(Catalog.shared.allCredits, id: \.image) { c in
                    Link(destination: URL(string: c.source)!) {
                        VStack(alignment: .leading) { Text(c.author).foregroundStyle(Theme.ink); Text("\(c.license) · \(c.image)").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    }
                }
            }
        }
        .navigationTitle("图片来源").navigationBarTitleDisplayMode(.inline)
    }
}
