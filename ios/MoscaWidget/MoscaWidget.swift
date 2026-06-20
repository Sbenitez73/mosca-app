import WidgetKit
import SwiftUI

// ── containerBackground requires iOS 17 ──────────────────────────────────────
private extension View {
    @ViewBuilder
    func widgetBackgroundColor(_ color: Color) -> some View {
        if #available(iOS 17, *) {
            containerBackground(color, for: .widget)
        } else {
            self
        }
    }

    @ViewBuilder
    func widgetBackgroundGradient(_ gradient: LinearGradient) -> some View {
        if #available(iOS 17, *) {
            containerBackground(gradient, for: .widget)
        } else {
            self
        }
    }
}

// ── Shared colors ─────────────────────────────────────────────────────────────
private let emerald     = Color(red: 0.04, green: 0.49, blue: 0.29)
private let emeraldDark = Color(red: 0.04, green: 0.37, blue: 0.22)

// ── Widget entry + provider ───────────────────────────────────────────────────
struct MoscaEntry: TimelineEntry { let date: Date }

struct MoscaProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoscaEntry { MoscaEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (MoscaEntry) -> Void) {
        completion(MoscaEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MoscaEntry>) -> Void) {
        completion(Timeline(entries: [MoscaEntry(date: Date())], policy: .never))
    }
}

// ── Small widget ──────────────────────────────────────────────────────────────
private struct MoscaWidgetSmallView: View {
    var body: some View {
        ZStack {
            emerald
            VStack(spacing: 6) {
                Image("MoscaIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                Text("Gasto\nrápido")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
            }
        }
    }
}

// ── Medium widget ─────────────────────────────────────────────────────────────
private struct MoscaWidgetMediumView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [emerald, emeraldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HStack(spacing: 0) {
                // Brand side
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Image("MoscaIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 38, height: 38)
                        Text("Mosca")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text("Registra tus gastos\nrápidamente")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(2)
                }
                Spacer()
                // Tap target
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// ── Widget configurations ─────────────────────────────────────────────────────
struct MoscaSmallWidget: Widget {
    let kind = "MoscaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoscaProvider()) { _ in
            MoscaWidgetSmallView()
                .widgetURL(URL(string: "mosca://quick-add"))
                .widgetBackgroundColor(emerald)
        }
        .configurationDisplayName("Gasto rápido")
        .description("Registra un gasto en un toque.")
        .supportedFamilies([.systemSmall])
    }
}

struct MoscaMediumWidget: Widget {
    let kind = "MoscaWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoscaProvider()) { _ in
            MoscaWidgetMediumView()
                .widgetURL(URL(string: "mosca://quick-add"))
                .widgetBackgroundGradient(
                    LinearGradient(
                        colors: [emerald, emeraldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .configurationDisplayName("Mosca — Gasto rápido")
        .description("Registra un gasto en un toque desde tu pantalla de inicio.")
        .supportedFamilies([.systemMedium])
    }
}

// ── Bundle ────────────────────────────────────────────────────────────────────
@main
struct MoscaWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoscaSmallWidget()
        MoscaMediumWidget()
    }
}
