import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct Candidate: Identifiable, Hashable, Sendable { let id: String; let speciesID: String; let likelihood: String }

/// Swap `MockIdentifier` for a real model-backed implementation later.
protocol SpeciesIdentifier: Sendable {
    var isDemo: Bool { get }
    func identify(photo: Data) async throws -> [Candidate]
}

struct MockIdentifier: SpeciesIdentifier {
    let isDemo = true
    func identify(photo: Data) async throws -> [Candidate] {
        try await Task.sleep(for: .seconds(1.5))
        // Deterministic from the photo bytes so the demo is stable; NOT a real result.
        let ids = Catalog.shared.species.map(\.id)
        guard ids.count >= 3 else { return [] }
        let seed = photo.prefix(64).reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF }
        let picks = (0..<3).map { ids[(seed + $0 * 7) % ids.count] }
        var uniq: [String] = []; for p in picks where !uniq.contains(p) { uniq.append(p) }
        let bands = ["较高可能", "可能", "较低"]
        return uniq.enumerated().map { Candidate(id: $1, speciesID: $1, likelihood: bands[$0]) }
    }
}

struct IdentifyView: View {
    enum Mode { case explore, pick }
    var mode: Mode = .explore
    var onPick: ((String, String?) -> Void)? = nil

    enum Phase { case start, analyzing, result, none, failed, saved }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @Query(sort: \DiveLogEntry.date, order: .reverse) private var logs: [DiveLogEntry]
    @State private var phase: Phase = .start
    @State private var item: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoFile: String?
    @State private var candidates: [Candidate] = []
    @State private var chosen: String?
    @State private var showCamera = false
    @State private var cameraDenied = false
    @State private var task: Task<Void, Never>?
    @State private var showCreate = false
    @State private var showLogPicker = false
    @State private var goLibrary = false
    @State private var savedLogID: UUID?
    @State private var addedFavorite = false
    private let service: any SpeciesIdentifier = MockIdentifier()
    private let catalog = Catalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "flask")
                        Text("演示模式：结果为模拟内容，不代表真实识别。").font(.footnote)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.tint, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(Theme.ink)
                    switch phase {
                    case .start: start
                    case .analyzing: analyzing
                    case .result: result
                    case .none: noneView
                    case .failed: failedView
                    case .saved: savedView
                    }
                }
                .padding(.horizontal, Theme.margin).padding(.bottom, 100)
            }
            .screenBackground()
            .navigationTitle(phase == .result ? "识别结果" : "识别").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { cleanup(); dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("关闭") } }
            .safeAreaInset(edge: .bottom) { if phase == .result { bottomBar } }
            .onChange(of: item) { _, new in
                guard let new else { return }
                Task { if let d = try? await new.loadTransferable(type: Data.self) { begin(d) } else { phase = .failed } }
            }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { data in showCamera = false; if let data { begin(data) } }.ignoresSafeArea() }
            .sheet(isPresented: $showCreate) {
                LogEditorView(presetSite: nil, presetSpecies: chosen.map { [$0] } ?? [], presetPhotos: photoFile.map { [$0] } ?? [], presetStatus: .confirmed) { id in savedLogID = id; phase = .saved }
            }
            .sheet(isPresented: $showLogPicker) { logPicker }
            .navigationDestination(isPresented: $goLibrary) { LibraryView() }
        }
    }

    private var start: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.system(size: 48)).foregroundStyle(Theme.accent)
                Text("选一张水下照片").font(.headline).foregroundStyle(Theme.ink)
                Text("识别结果只是参考，请结合图鉴确认").font(.subheadline).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).frame(height: 240)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundStyle(Theme.accent.opacity(0.6)))
            if cameraDenied {
                EmptyState(symbol: "camera.fill", title: "需要相机权限", message: "请在设置中允许 Dive into ocean 使用相机", button: "打开设置") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) }
                }
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { requestCamera() } label: { Label("拍照", systemImage: "camera").frame(maxWidth: .infinity, minHeight: 50) }.buttonStyle(.borderedProminent)
            }
            PhotosPicker(selection: $item, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: 50)
            }.buttonStyle(.bordered).accessibilityIdentifier("pick-photo")
        }
    }

    private var photoView: some View {
        Group {
            if let d = photoData, let img = UIImage(data: d) { Color.clear.overlay { Image(uiImage: img).resizable().scaledToFill() }.clipped() } else { Theme.tint }
        }
        .frame(maxWidth: .infinity).aspectRatio(4/3, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var analyzing: some View {
        VStack(spacing: 12) {
            photoView.overlay {
                VStack(spacing: 4) { ProgressView(); Text("正在识别…").font(.subheadline); Text("演示模式，不会上传你的照片").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            Button("取消") { task?.cancel(); phase = .start }.buttonStyle(.bordered)
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 16) {
            photoView
            Label("以下是可能的候选，结果不一定准确，请对照特征确认。", systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(Theme.warning)
            if let top = candidates.first, let sp = catalog.species(top.speciesID) {
                let sel = chosen == sp.id
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("最可能").font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3).background(Theme.accent, in: Capsule()).foregroundStyle(Theme.onAccent); Text("候选 1，仅供参考").font(.caption).foregroundStyle(Theme.inkSecondary); Spacer(); selMark(sel) }
                    HStack(spacing: 12) {
                        BundledImage(name: sp.image).frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading) { Text("可能是 \(sp.nameZh)").font(.headline); Text(sp.scientific).font(.caption.italic()).foregroundStyle(Theme.inkSecondary); Text(top.likelihood).font(.caption) }
                            .foregroundStyle(Theme.ink)
                    }
                    Text("关键特征").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    BulletList(items: Array(sp.features.prefix(3)))
                    NavigationLink(value: Route.species(sp.id)) { Text("查看图鉴").font(.subheadline) }
                }
                .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent, lineWidth: 2))
                .onTapGesture { chosen = sp.id }
                .accessibilityElement(children: .contain)
                .navigationDestination(for: Route.self) { r in if case .species(let id) = r { SpeciesDetailView(speciesID: id) } }
            }
            if candidates.count > 1 {
                Text("其他可能").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                ForEach(Array(candidates.dropFirst().enumerated()), id: \.element.id) { i, c in
                    if let sp = catalog.species(c.speciesID) {
                        Button { chosen = sp.id } label: {
                            HStack { SpeciesRow(species: sp, trailing: c.likelihood); selMark(chosen == sp.id) }
                        }.buttonStyle(.plain)
                        .accessibilityLabel("候选 \(i + 2)，\(sp.nameZh)，\(c.likelihood)")
                    }
                }
            }
        }
    }

    private func selMark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.accent : Theme.inkSecondary)
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            let isTop = chosen == candidates.first?.speciesID
            Button { confirm() } label: { Text(isTop ? "就是它" : "选这一个").frame(maxWidth: .infinity, minHeight: 50) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("confirm-species")
            Button("都不对") { phase = .none }.frame(minHeight: 44)
        }
        .padding(.horizontal, Theme.margin).padding(.top, 8).background(.regularMaterial)
    }

    private var noneView: some View {
        VStack(spacing: 12) {
            EmptyState(symbol: "questionmark.circle", title: "没有合适的候选", message: "可以去图鉴里自己找找", button: "去图鉴") { goLibrary = true }
            Button("重新选照片") { phase = .start }.buttonStyle(.bordered)
        }
    }
    private var failedView: some View {
        VStack(spacing: 12) {
            ErrorBanner(title: "识别没有成功") { phase = .start }
            Text("换一张更清晰的照片再试试").font(.subheadline).foregroundStyle(Theme.inkSecondary)
        }
    }

    private var savedView: some View {
        let sp = chosen.flatMap { catalog.species($0) }
        return VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Theme.accent).symbolEffect(.bounce, value: phase == .saved)
            Text("已选择 \(sp?.nameZh ?? "")").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            if savedLogID != nil { Text("已添加到日志").foregroundStyle(Theme.inkSecondary) }
            if savedLogID == nil {
                Button { chooseLog() } label: { Label("添加到日志", systemImage: "book.closed").frame(maxWidth: .infinity, minHeight: 50) }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-to-log")
            }
            if let c = chosen { IdentifyFavoriteButton(speciesID: c) }
            Button("完成") { cleanup(keepPhoto: savedLogID != nil); dismiss() }.buttonStyle(.bordered).frame(minHeight: 44)
        }
        .padding(.top, 24).frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: phase == .saved)
    }

    private var logPicker: some View {
        NavigationStack {
            List {
                Button { showLogPicker = false; showCreate = true } label: { Label("新建日志并添加", systemImage: "plus.circle") }
                if !logs.isEmpty {
                    Section("添加到现有日志") {
                        ForEach(logs) { l in
                            Button {
                                if let c = chosen, !l.sightings.contains(where: { $0.speciesID == c }) { l.sightings.append(Sighting(speciesID: c, status: .confirmed, photoFile: photoFile)) }
                                if let f = photoFile, !l.photoFiles.contains(f) { l.photoFiles.append(f) }
                                try? context.save(); savedLogID = l.id; showLogPicker = false
                            } label: {
                                VStack(alignment: .leading) { Text(catalog.site(l.siteID)?.nameZh ?? "—").foregroundStyle(Theme.ink); Text(l.date.formatted(dateFormat)).font(.caption).foregroundStyle(Theme.inkSecondary) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加到日志").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium, .large])
    }

    // MARK: actions
    private func requestCamera() {
        switch AVCaptureAuth.status {
        case .denied: cameraDenied = true
        default: AVCaptureAuth.request { ok in if ok { showCamera = true } else { cameraDenied = true } }
        }
    }
    private func begin(_ data: Data) {
        photoData = data; phase = .analyzing
        photoFile = ImageStore.savePhoto(data)
        task = Task {
            do {
                let c = try await service.identify(photo: data)
                if Task.isCancelled { return }
                candidates = c; chosen = c.first?.speciesID
                phase = c.isEmpty ? .failed : .result
            } catch { if !Task.isCancelled { phase = .failed } }
        }
    }
    private func confirm() {
        guard let chosen else { return }
        if mode == .pick { onPick?(chosen, photoFile); dismiss(); return }
        phase = .saved
    }
    private func chooseLog() { if logs.isEmpty { showCreate = true } else { showLogPicker = true } }
    private func cleanup(keepPhoto: Bool = false) {
        task?.cancel()
        if !keepPhoto, mode == .explore, let f = photoFile { ImageStore.deletePhoto(f) }
    }
}

struct IdentifyFavoriteButton: View {
    let speciesID: String
    var body: some View { SpeciesFavoriteBar(speciesID: speciesID, name: Catalog.shared.species(speciesID)?.nameZh ?? "").frame(minHeight: 50) }
}

import AVFoundation
enum AVCaptureAuth {
    static var status: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }
    static func request(_ done: @escaping @MainActor (Bool) -> Void) {
        if status == .authorized { Task { @MainActor in done(true) }; return }
        AVCaptureDevice.requestAccess(for: .video) { ok in Task { @MainActor in done(ok) } }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var done: (Data?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (Data?) -> Void
        init(done: @escaping (Data?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
