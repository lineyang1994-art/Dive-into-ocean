import SwiftUI
import SwiftData
import PhotosUI

struct LogCard: View {
    let log: DiveLogEntry
    private let catalog = Catalog.shared
    var body: some View {
        let site = catalog.site(log.siteID)
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let f = log.photoFiles.first { UserPhoto(file: f) }
                else { ZStack { Theme.tint; Image(systemName: "water.waves").font(.largeTitle).foregroundStyle(Theme.accent.opacity(0.6)) } }
            }
            .frame(maxWidth: .infinity).aspectRatio(16/9, contentMode: .fit).clipped()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site?.nameZh ?? "未知潜点").font(.headline).foregroundStyle(Theme.ink)
                        Text(site?.place ?? "").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Text(log.date.formatted(dateFormat)).font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                HStack(spacing: 14) {
                    Label("\(fmtNum(log.maxDepth)) 米", systemImage: "arrow.down.to.line")
                    Label("\(log.duration) 分钟", systemImage: "clock")
                    Label("发现 \(log.sightings.count) 种", systemImage: "sparkles")
                }.font(.caption).foregroundStyle(Theme.inkSecondary)
            }.padding(16)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct LogListView: View {
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    @Environment(\.startLog) private var startLog
    @State private var path = NavigationPath()
    @State private var showCreate = false
    @State private var toast: String?

    private var groups: [(String, [DiveLogEntry])] {
        let g = Dictionary(grouping: logs) { $0.date.formatted(.dateTime.year().month(.wide).locale(zhLocale)) }
        return logs.reduce(into: [String]()) { acc, l in let k = l.date.formatted(.dateTime.year().month(.wide).locale(zhLocale)); if !acc.contains(k) { acc.append(k) } }
            .map { ($0, g[$0]!) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if logs.isEmpty {
                    EmptyState(symbol: "book.closed", title: "还没有日志", message: "记下第一次下潜，和那天遇见的生物", button: "写第一篇日志") { showCreate = true }
                        .padding(.top, 80)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(groups, id: \.0) { month, items in
                            Text(month).font(.footnote.weight(.semibold)).foregroundStyle(Theme.inkSecondary).padding(.top, 8)
                            ForEach(items) { l in NavigationLink(value: Route.log(l.id)) { LogCard(log: l) }.buttonStyle(.plain) }
                        }
                    }.padding(.horizontal, Theme.margin).padding(.bottom, 24)
                }
            }
            .screenBackground()
            .navigationTitle("日志")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Label("新建", systemImage: "plus") }.accessibilityIdentifier("new-log") } }
            .routes()
            .sheet(isPresented: $showCreate) { LogEditorView(presetSite: nil) { id in toast = "已保存"; path.append(Route.log(id)) } }
            .toast($toast)
        }
    }
}

struct PickedPhoto: Identifiable { let id = UUID(); let file: String }

struct LogEditorView: View {
    var editing: DiveLogEntry? = nil
    var presetSite: String?
    var presetSpecies: [String] = []
    var presetPhotos: [String] = []
    var presetStatus: IdentificationStatus = .manual
    var onSaved: (UUID) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var siteID: String?
    @State private var date = Date()
    @State private var depth = ""
    @State private var duration = ""
    @State private var temp = ""
    @State private var vis = ""
    @State private var notes = ""
    @State private var photos: [String] = []
    @State private var speciesEntries: [(String, IdentificationStatus)] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showSpecies = false
    @State private var showIdentify = false
    @State private var showDiscard = false
    @State private var tried = false
    @State private var saveError = false
    @State private var loaded = false
    private let catalog = Catalog.shared

    private var depthV: Double? { Double(depth.replacingOccurrences(of: ",", with: ".")) }
    private var durV: Int? { Int(duration) }
    private var dirty: Bool { siteID != nil || !depth.isEmpty || !duration.isEmpty || !notes.isEmpty || !photos.isEmpty || !speciesEntries.isEmpty }
    private var valid: Bool { siteID != nil && (depthV ?? 0) > 0 && (durV ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                if saveError { Section { ErrorBanner(title: "没有保存成功，请重试") }.listRowBackground(Color.clear) }
                Section("潜点") {
                    NavigationLink {
                        SitePicker(selection: $siteID)
                    } label: {
                        HStack { Text("潜点"); Spacer()
                            Text(siteID.flatMap { catalog.site($0)?.nameZh } ?? "请选择潜点").foregroundStyle(siteID == nil ? Theme.inkSecondary : Theme.ink) }
                    }
                    .accessibilityIdentifier("site-row")
                    if tried && siteID == nil { Text("请选择潜点").font(.caption).foregroundStyle(Theme.error) }
                    DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                Section("潜水数据") {
                    field("最大深度（米）", $depth, decimal: true, invalid: tried && (depthV ?? 0) <= 0, msg: depth.isEmpty ? "请填写最大深度" : "数值需大于 0", id: "depth-field")
                    field("潜水时长（分钟）", $duration, decimal: false, invalid: tried && (durV ?? 0) <= 0, msg: duration.isEmpty ? "请填写潜水时长" : "数值需大于 0", id: "duration-field")
                    field("水温（°C，选填）", $temp, decimal: true, invalid: false, msg: "", id: "temp-field")
                    field("能见度（米，选填）", $vis, decimal: true, invalid: false, msg: "", id: "vis-field")
                }
                Section("照片") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                                VStack { Image(systemName: "plus"); Text("添加照片").font(.caption2) }
                                    .frame(width: 88, height: 88)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(Theme.accent))
                            }
                            ForEach(photos, id: \.self) { f in
                                UserPhoto(file: f).frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(alignment: .topTrailing) {
                                        Button { photos.removeAll { $0 == f } } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.6)) }
                                            .buttonStyle(.plain).padding(4).accessibilityLabel("移除照片")
                                    }
                            }
                        }.padding(.vertical, 4)
                    }
                    if !photos.isEmpty { Text("已添加 \(photos.count) 张").font(.caption).foregroundStyle(Theme.inkSecondary) }
                }
                Section("这次发现的生物") {
                    if speciesEntries.isEmpty { Text("还没有添加生物").foregroundStyle(Theme.inkSecondary) }
                    ForEach(speciesEntries.map(\.0), id: \.self) { id in
                        if let s = catalog.species(id) {
                            SpeciesRow(species: s, trailing: speciesEntries.first { $0.0 == id }?.1.label)
                        }
                    }
                    .onDelete { idx in speciesEntries.remove(atOffsets: idx) }
                    Button { showSpecies = true } label: { Label("从图鉴添加", systemImage: "plus.circle") }
                    Button { showIdentify = true } label: { Label("识别照片后添加", systemImage: "camera.viewfinder") }
                }
                Section("笔记") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $notes).frame(minHeight: 120)
                        if notes.isEmpty { Text("写下今天的感受、遇到的事…").foregroundStyle(Theme.inkSecondary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新建日志" : "编辑日志").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if dirty && editing == nil { showDiscard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.fontWeight(.semibold).accessibilityIdentifier("save-log") }
            }
            .confirmationDialog("放弃这篇日志？", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("放弃", role: .destructive) { photos.forEach(ImageStore.deletePhoto); dismiss() }
                Button("继续编辑", role: .cancel) {}
            } message: { Text("已填写的内容不会保存") }
            .sheet(isPresented: $showSpecies) {
                SpeciesPicker(siteID: siteID, selected: Set(speciesEntries.map(\.0))) { ids in
                    for id in ids where !speciesEntries.contains(where: { $0.0 == id }) { speciesEntries.append((id, .manual)) }
                }
            }
            .fullScreenCover(isPresented: $showIdentify) {
                IdentifyView(mode: .pick) { id, file in
                    if !speciesEntries.contains(where: { $0.0 == id }) { speciesEntries.append((id, .confirmed)) }
                    if let file, !photos.contains(file) { photos.append(file) }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task {
                    for it in items { if let d = try? await it.loadTransferable(type: Data.self), let f = ImageStore.savePhoto(d) { photos.append(f) } }
                    pickerItems = []
                }
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                if let e = editing {
                    siteID = e.siteID; date = e.date; depth = fmtNum(e.maxDepth); duration = String(e.duration)
                    temp = e.temperature.map(fmtNum) ?? ""; vis = e.visibility.map(fmtNum) ?? ""; notes = e.notes; photos = e.photoFiles
                    speciesEntries = e.sightings.map { ($0.speciesID, $0.status) }
                } else {
                    siteID = presetSite; photos = presetPhotos
                    speciesEntries = presetSpecies.map { ($0, presetStatus) }
                }
            }
        }
        .interactiveDismissDisabled(dirty && editing == nil)
    }

    private func field(_ title: String, _ text: Binding<String>, decimal: Bool, invalid: Bool, msg: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title); Spacer(); TextField("0", text: text).multilineTextAlignment(.trailing).keyboardType(decimal ? .decimalPad : .numberPad).frame(width: 90).accessibilityIdentifier(id) }
            if invalid { Text(msg).font(.caption).foregroundStyle(Theme.error) }
        }
    }

    private func save() {
        tried = true
        guard valid, let siteID, let d = depthV, let m = durV else { return }
        let t = Double(temp.replacingOccurrences(of: ",", with: ".")), v = Double(vis.replacingOccurrences(of: ",", with: "."))
        let entry: DiveLogEntry
        if let e = editing {
            entry = e
            e.siteID = siteID; e.date = date; e.maxDepth = d; e.duration = m; e.temperature = t; e.visibility = v; e.notes = notes
            for gone in e.photoFiles where !photos.contains(gone) { ImageStore.deletePhoto(gone) }
            e.photoFiles = photos
            for s in e.sightings where !speciesEntries.contains(where: { $0.0 == s.speciesID }) { context.delete(s) }
        } else {
            entry = DiveLogEntry(date: date, siteID: siteID, maxDepth: d, duration: m, temperature: t, visibility: v, notes: notes, photoFiles: photos)
            context.insert(entry)
        }
        for (sid, st) in speciesEntries where !entry.sightings.contains(where: { $0.speciesID == sid }) {
            entry.sightings.append(Sighting(speciesID: sid, status: st))
        }
        do { try context.save(); let id = entry.id; dismiss(); onSaved(id) } catch { saveError = true }
    }
}

struct SitePicker: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    var body: some View {
        List(Catalog.shared.searchSites(q)) { s in
            Button { selection = s.id; dismiss() } label: {
                HStack {
                    VStack(alignment: .leading) { Text(s.nameZh).foregroundStyle(Theme.ink); Text("\(s.name) · \(s.place)").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    Spacer(); if selection == s.id { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                }.frame(minHeight: 44)
            }
        }
        .navigationTitle("选择潜点").searchable(text: $q, prompt: "搜索国家、地区或潜点名")
    }
}

struct SpeciesPicker: View {
    var siteID: String?
    var selected: Set<String>
    var done: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var picks: Set<String> = []
    private let catalog = Catalog.shared
    var body: some View {
        NavigationStack {
            let all = catalog.searchSpecies(q)
            let local = Set(siteID.map { catalog.species(at: $0).map(\.0.id) } ?? [])
            List {
                if !local.isEmpty && q.isEmpty {
                    Section("此潜点常见") { ForEach(all.filter { local.contains($0.id) }) { row($0) } }
                    Section("全部") { ForEach(all.filter { !local.contains($0.id) }) { row($0) } }
                } else { ForEach(all) { row($0) } }
            }
            .navigationTitle("从图鉴添加").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $q, prompt: "搜索中文名、英文名或学名")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { done(Array(picks)); dismiss() } }
            }
        }
    }
    private func row(_ s: Species) -> some View {
        let on = picks.contains(s.id) || selected.contains(s.id)
        return Button { if picks.contains(s.id) { picks.remove(s.id) } else if !selected.contains(s.id) { picks.insert(s.id) } } label: {
            HStack { SpeciesRow(species: s); Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.accent : Theme.inkSecondary) }
        }.buttonStyle(.plain)
    }
}

struct LogDetailView: View {
    let logID: UUID
    @Query private var logs: [DiveLogEntry]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false
    private let catalog = Catalog.shared
    init(logID: UUID) { self.logID = logID; _logs = Query(filter: #Predicate<DiveLogEntry> { $0.id == logID }) }

    var body: some View {
        if let log = logs.first {
            let site = catalog.site(log.siteID)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if log.photoFiles.isEmpty {
                        ZStack { Theme.tint; Image(systemName: "water.waves").font(.system(size: 44)).foregroundStyle(Theme.accent.opacity(0.6)) }.frame(height: 200)
                    } else {
                        TabView { ForEach(log.photoFiles, id: \.self) { UserPhoto(file: $0).frame(maxWidth: .infinity).clipped() } }
                            .tabViewStyle(.page).aspectRatio(4/3, contentMode: .fit)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(site?.nameZh ?? "未知潜点").font(.display).foregroundStyle(Theme.ink)
                        Text("\(site?.place ?? "") · \(log.date.formatted(dateFormat))").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }.padding(.horizontal, Theme.margin)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("潜水数据").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 12) {
                            StatTile(value: "\(fmtNum(log.maxDepth)) 米", label: "最大深度")
                            StatTile(value: "\(log.duration) 分钟", label: "潜水时长")
                            if let t = log.temperature { StatTile(value: "\(fmtNum(t)) °C", label: "水温") }
                        }
                        if let v = log.visibility { Label("能见度 \(fmtNum(v)) 米", systemImage: "eye").font(.subheadline).foregroundStyle(Theme.inkSecondary) }
                    }.padding(.horizontal, Theme.margin)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("发现的生物").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        if log.sightings.isEmpty { Text("这篇日志还没有记录生物").foregroundStyle(Theme.inkSecondary) }
                        else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(log.sightings.sorted { $0.createdAt < $1.createdAt }) { s in
                                    if let sp = catalog.species(s.speciesID) {
                                        NavigationLink(value: Route.species(sp.id)) {
                                            VStack(spacing: 4) {
                                                BundledImage(name: sp.image).aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped().aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                                                Text(sp.nameZh).font(.caption).foregroundStyle(Theme.ink).lineLimit(2)
                                                Text(s.status.label).font(.caption2).foregroundStyle(Theme.inkSecondary)
                                            }
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }.padding(.horizontal, Theme.margin)
                    if !log.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) { Text("笔记").font(.title3.weight(.semibold)); Text(log.notes) }
                            .foregroundStyle(Theme.ink).padding(.horizontal, Theme.margin)
                    }
                    if let site {
                        NavigationLink(value: Route.site(site.id)) {
                            HStack { Label("查看潜点", systemImage: "mappin.and.ellipse"); Spacer(); Image(systemName: "chevron.right") }
                                .padding(16).frame(minHeight: 44).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).padding(.horizontal, Theme.margin)
                    }
                }.padding(.bottom, 32)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑", systemImage: "pencil") { editing = true }
                        Button("删除", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $editing) { LogEditorView(editing: log, presetSite: nil) { _ in } }
            .confirmationDialog("删除这篇日志？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) { log.photoFiles.forEach(ImageStore.deletePhoto); context.delete(log); try? context.save(); dismiss() }
                Button("取消", role: .cancel) {}
            } message: { Text("日志里的发现记录也会一并移除，无法恢复") }
        } else {
            EmptyState(symbol: "book.closed", title: "这篇日志不存在")
        }
    }
}
