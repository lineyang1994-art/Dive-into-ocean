import SwiftUI
import SwiftData

enum Theme {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let accent = dyn(0x087F8C, 0x66C9CC)
    static let onAccent = dyn(0xFFFFFF, 0x082B40)
    static let bg = dyn(0xF7F8F5, 0x061C2B)
    static let surface = dyn(0xFFFFFF, 0x0D2B3E)
    static let tint = dyn(0xD9F1ED, 0x123A4A)
    static let ink = dyn(0x082B40, 0xF2F7F6)
    static let inkSecondary = dyn(0x4A6575, 0xA9C0C9)
    static let favorite = dyn(0xD9486A, 0xFF7A98)
    static let warning = dyn(0xB26A00, 0xF2B35E)
    static let error = dyn(0xB3261E, 0xFF8A80)
    static let margin: CGFloat = 20
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

extension Font {
    static var display: Font { .system(.largeTitle, design: .serif).weight(.semibold) }
}

extension View {
    func screenBackground() -> some View { background(Theme.bg.ignoresSafeArea()) }
}

// MARK: Images

struct BundledImage: View {
    let name: String
    var body: some View {
        if name.isEmpty {
            ZStack {
                LinearGradient(colors: [Color(red: 0.03, green: 0.17, blue: 0.25), Color(red: 0.03, green: 0.50, blue: 0.55)], startPoint: .bottom, endPoint: .top)
                Image(systemName: "water.waves").font(.largeTitle).foregroundStyle(.white.opacity(0.35))
            }
        } else if let img = ImageStore.bundled(name) {
            Color.clear.overlay { Image(uiImage: img).resizable().scaledToFill() }.clipped()
        } else {
            ZStack {
                LinearGradient(colors: [Theme.tint, Theme.accent.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                Image(systemName: "photo").foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

struct UserPhoto: View {
    let file: String
    var body: some View {
        if let img = ImageStore.photo(file) {
            Color.clear.overlay { Image(uiImage: img).resizable().scaledToFill() }.clipped()
        } else {
            ZStack { Theme.tint; Image(systemName: "photo").foregroundStyle(Theme.inkSecondary) }
        }
    }
}

struct Scrim: View {
    var body: some View {
        LinearGradient(colors: [Theme.ink.opacity(0), Color(UIColor(hex: 0x082B40)).opacity(0.72)], startPoint: .init(x: 0.5, y: 0.45), endPoint: .bottom)
    }
}

// MARK: Favorites

struct FavoriteButton: View {
    let type: String
    let id: String
    let label: String
    @Environment(\.modelContext) private var context
    @Query private var favs: [FavoriteItem]
    init(type: String, id: String, label: String) {
        self.type = type; self.id = id; self.label = label
        _favs = Query(filter: #Predicate<FavoriteItem> { $0.targetType == type && $0.targetID == id })
    }
    var isOn: Bool { !favs.isEmpty }
    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.35)) {
                if let f = favs.first { context.delete(f) } else { context.insert(FavoriteItem(type: type, id: id)) }
                try? context.save()
            }
        } label: {
            Image(systemName: isOn ? "heart.fill" : "heart")
                .foregroundStyle(isOn ? Theme.favorite : Color.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isOn)
        .accessibilityLabel(isOn ? "取消收藏 \(label)" : "收藏 \(label)")
        .accessibilityValue(isOn ? "已收藏" : "未收藏")
    }
}

// MARK: Components

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Theme.inkSecondary) }
            }
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 2) { Text(action); Image(systemName: "chevron.right").font(.caption) }
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
        }
    }
}

struct Chip: View {
    let text: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.subheadline)
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(selected ? Theme.accent : Theme.tint, in: Capsule())
                .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TagText: View {
    let text: String
    var body: some View {
        Text(text).font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.tint, in: Capsule()).foregroundStyle(Theme.ink)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    var message: String? = nil
    var button: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(Theme.accent.opacity(0.7)).accessibilityHidden(true)
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            if let message { Text(message).font(.subheadline).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center) }
            if let button, let action {
                Button(button, action: action).buttonStyle(.borderedProminent).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity).padding(32)
    }
}

struct ErrorBanner: View {
    let title: String
    var retry: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.error)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            if let retry { Button("重试", action: retry).buttonStyle(.bordered) }
        }
        .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct DemoBadge: View {
    var body: some View {
        Label("演示模式", systemImage: "flask").font(.caption.weight(.medium)).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.tint, in: Capsule()).foregroundStyle(Theme.ink)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct CalloutCard: View {
    let symbol: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(text).font(.subheadline).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(16).background(Theme.tint, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct BulletList: View {
    let items: [String]
    var symbol: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { t in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let symbol { Image(systemName: symbol).font(.caption).foregroundStyle(Theme.accent) }
                    else { Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Theme.accent) }
                    Text(t).foregroundStyle(Theme.ink)
                }
            }
        }
    }
}

struct SpeciesRow: View {
    let species: Species
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            BundledImage(name: species.image).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(species.nameZh).font(.headline).foregroundStyle(Theme.ink)
                Text(species.nameEn).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                Text(species.scientific).font(.caption.italic()).foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
            if let trailing { TagText(text: trailing) }
        }
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

struct SpeciesCard: View {
    let species: Species
    var width: CGFloat = 160
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BundledImage(name: species.image).frame(width: width, height: width).clipShape(RoundedRectangle(cornerRadius: 16))
            Text(species.nameZh).font(.headline).foregroundStyle(Theme.ink).lineLimit(2)
            if species.curated { Text(species.nameEn).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1) }
            if species.nameZh != species.scientific { Text(species.scientific).font(.caption.italic()).foregroundStyle(Theme.inkSecondary).lineLimit(1) }
        }
        .frame(width: width, alignment: .leading)
    }
}

struct SitePhotoCard: View {
    let site: Site
    var width: CGFloat? = nil
    var height: CGFloat
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            BundledImage(name: site.image).frame(maxWidth: .infinity).frame(height: height).clipped()
            Scrim()
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name).font(.headline).foregroundStyle(.white)
                Text(site.place).font(.caption).foregroundStyle(.white.opacity(0.85))
                HStack { ForEach(site.types, id: \.self) { TagText(text: $0) } }.padding(.top, 2)
            }
            .padding(16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            FavoriteButton(type: "site", id: site.id, label: site.name).padding(10)
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message).font(.subheadline.weight(.medium)).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule()).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task { try? await Task.sleep(for: .seconds(2)); withAnimation { self.message = nil } }
            }
        }
        .animation(.spring(duration: 0.35), value: message)
    }
}
extension View { func toast(_ m: Binding<String?>) -> some View { modifier(ToastModifier(message: m)) } }

let zhLocale = Locale(identifier: "zh_CN")
let dateFormat: Date.FormatStyle = Date.FormatStyle(date: .long, time: .omitted).locale(zhLocale)
func fmtNum(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
