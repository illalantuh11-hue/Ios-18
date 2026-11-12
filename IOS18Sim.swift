// IOS18Sim.swift — симулятор интерфейса iOS 18 на SwiftUI (iOS 17+)
// Один файл: содержит @main, поэтому в проекте должен быть только один такой файл.
import SwiftUI
import UIKit

// MARK: - Данные

struct AppItem: Identifiable, Equatable {
    let id: String, name: String, emoji: String, color: Color
}

let allApps: [AppItem] = [
    .init(id: "ph", name: "Фото", emoji: "🌄", color: .white),
    .init(id: "cam", name: "Камера", emoji: "📷", color: Color(white: 0.4)),
    .init(id: "clk", name: "Часы", emoji: "🕘", color: Color(white: 0.11)),
    .init(id: "cal", name: "Календарь", emoji: "📅", color: .white),
    .init(id: "wx", name: "Погода", emoji: "⛅", color: Color(red: 0.23, green: 0.55, blue: 1)),
    .init(id: "map", name: "Карты", emoji: "🗺️", color: .green),
    .init(id: "nt", name: "Заметки", emoji: "📝", color: .yellow),
    .init(id: "rem", name: "Напоминания", emoji: "✅", color: .orange),
    .init(id: "stk", name: "Акции", emoji: "📈", color: Color(white: 0.11)),
    .init(id: "bk", name: "Книги", emoji: "📚", color: .orange),
    .init(id: "hl", name: "Здоровье", emoji: "❤️", color: .white),
    .init(id: "set", name: "Настройки", emoji: "⚙️", color: .gray),
    .init(id: "tel", name: "Телефон", emoji: "📞", color: .green),
    .init(id: "web", name: "Браузер", emoji: "🧭", color: .blue),
    .init(id: "msg", name: "Сообщения", emoji: "💬", color: .green),
    .init(id: "mus", name: "Музыка", emoji: "🎵", color: .pink),
]

/// Собирает положение иконок, чтобы окно приложения могло «вырасти» из нужной иконки.
struct IconFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Корневой экран

struct RootView: View {
    @State private var current: AppItem?
    @State private var iconRect: CGRect = .zero
    @State private var frames: [String: CGRect] = [:]
    @State private var p: CGFloat = 0      // 0 — иконка, 1 — полный экран
    @State private var dx: CGFloat = 0     // боковое смещение окна за пальцем
    @State private var lock: CGFloat = 0   // 0 — заблокирован, 1 — разблокирован
    @State private var popped = false

    private let spring = Animation.interpolatingSpring(stiffness: 260, damping: 30)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                LinearGradient(colors: [Color(red: 0.36, green: 0.29, blue: 1),
                                        Color(red: 0.75, green: 0.30, blue: 1),
                                        Color(red: 1.0, green: 0.42, blue: 0.53)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .onTapGesture(count: 2) { relock() }   // двойной тап по обоям — блокировка
                home
                if let app = current { window(app, size: size) }
                lockScreen(size: size)
                homeIndicator(size: size)
            }
            .coordinateSpace(name: "screen")
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onPreferenceChange(IconFramesKey.self) { frames = $0 }
    }

    // MARK: Домашний экран

    private var home: some View {
        // при открытии приложения экран приближается, при разблокировке «отъезжает»
        let s = (1 + 0.12 * p) * (1 + 0.1 * (1 - lock))
        return VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 26) {
                ForEach(Array(allApps.prefix(12).enumerated()), id: \.element.id) { i, a in
                    icon(a, index: i)
                }
            }
            .padding(.horizontal, 16).padding(.top, 80)
            Spacer()
            HStack {
                ForEach(Array(allApps.suffix(4).enumerated()), id: \.element.id) { i, a in
                    icon(a, index: 12 + i, showName: false)
                    if i < 3 { Spacer() }
                }
            }
            .padding(.horizontal, 22).frame(height: 92)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 14).padding(.bottom, 24)
        }
        .scaleEffect(s)
        .blur(radius: (1 - lock) * 8)
        .opacity(1 - p * 0.6)
    }

    private func icon(_ a: AppItem, index: Int, showName: Bool = true) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(a.color)
                Text(a.emoji).font(.system(size: 30))
            }
            .frame(width: 60, height: 60)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .opacity(current?.id == a.id && p > 0.001 ? 0 : 1)   // иконка прячется, пока окно «вместо неё»
            .background(GeometryReader { g in
                Color.clear.preference(key: IconFramesKey.self,
                                       value: [a.id: g.frame(in: .named("screen"))])
            })
            if showName {
                Text(a.name).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
            }
        }
        .frame(width: 72)
        .scaleEffect(popped ? 1 : 0.6).opacity(popped ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(Double(index) * 0.025), value: popped)
        .onTapGesture { open(a) }
    }

    // MARK: Окно приложения — прямоугольник, который растёт из иконки

    private func window(_ app: AppItem, size: CGSize) -> some View {
        let r = iconRect, q = max(p, 0), cp = min(max(p, 0), 1)
        let w = r.width + (size.width - r.width) * q
        let h = r.width + (size.height - r.width) * q
        let cx = r.midX + (size.width / 2 - r.midX) * q + dx * cp
        let cy = r.midY + (size.height / 2 - r.midY) * q
        let radius = 14 + 32 * cp
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(app.color)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(white: 0.95)).opacity(min(1, max(0, (cp - 0.1) * 1.5)))
            VStack(spacing: 14) {
                Text(app.emoji).font(.system(size: 30 + 90 * cp))
                Text(app.name).font(.title2.bold()).foregroundStyle(.black).opacity(cp * cp)
            }
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.25 + 0.15 * cp), radius: 4 + 20 * cp, y: 3)
        .blur(radius: 6 * sin(.pi * cp))          // моушн-блюр: максимум в середине движения
        .position(x: cx, y: cy)
    }

    // MARK: Экран блокировки

    private func lockScreen(size: CGSize) -> some View {
        VStack(spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: 19, weight: .medium))
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.system(size: 92, weight: .bold))
            }
            Spacer()
            Text("Проведите вверх").font(.footnote).opacity(0.8).padding(.bottom, 40)
        }
        .foregroundStyle(.white).padding(.top, 110)
        .frame(width: size.width, height: size.height)
        .background(Color.black.opacity(0.001))
        .offset(y: -lock * size.height)
        .opacity(1 - min(max(lock, 0), 1) * 0.8)
        .blur(radius: min(max(lock, 0), 1) * 6)
        .allowsHitTesting(lock < 1)
        .onTapGesture { unlock() }
        .gesture(
            DragGesture()
                .onChanged { v in noAnim { lock = max(-0.05, -v.translation.height / (size.height * 0.7)) } }
                .onEnded { v in
                    let go = lock > 0.3 || -v.predictedEndTranslation.height > size.height * 0.5
                    go ? unlock() : relock()
                }
        )
    }

    // MARK: Полоска «Домой»: тянем вверх — окно сжимается обратно в иконку

    private func homeIndicator(size: CGSize) -> some View {
        VStack {
            Spacer()
            Capsule().fill(.white).frame(width: 134, height: 5).shadow(radius: 2)
                .padding(.bottom, 8).frame(maxWidth: .infinity).frame(height: 70)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard current != nil else { return }
                            noAnim {
                                p = min(1.04, max(0, 1 + v.translation.height / (size.height * 0.55)))
                                dx = v.translation.width * 0.9
                            }
                        }
                        .onEnded { v in
                            guard current != nil else { return }
                            let moved = hypot(v.translation.width, v.translation.height) > 8
                            let flick = -v.predictedEndTranslation.height > size.height * 0.45
                            if !moved || p < 0.6 || flick { close() }
                            else { withAnimation(spring) { p = 1; dx = 0 } }
                        }
                )
        }
    }

    // MARK: Логика

    private func open(_ a: AppItem) {
        guard current == nil, lock >= 1 else { return }
        iconRect = frames[a.id] ?? .zero
        current = a
        haptic(.light)
        withAnimation(spring) { p = 1 }
    }

    private func close() {
        haptic(.light)
        withAnimation(spring, completionCriteria: .logicallyComplete) {
            p = 0; dx = 0
        } completion: {
            if p < 0.001 { current = nil }
        }
    }

    private func unlock() {
        haptic(.medium)
        popped = true
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 28)) { lock = 1 }
    }

    private func relock() {
        if current != nil { close() }
        popped = false
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 28)) { lock = 0 }
    }

    private func noAnim(_ body: () -> Void) {   // прерывает пружину, пока палец на экране
        var t = Transaction(); t.disablesAnimations = true; t.animation = nil
        withTransaction(t, body)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

@main
struct IOS18SimApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}
