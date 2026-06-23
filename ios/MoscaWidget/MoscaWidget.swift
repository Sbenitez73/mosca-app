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

// ── Balance widget ────────────────────────────────────────────────────────────

struct MoscaBalanceEntry: TimelineEntry {
    let date: Date
    let expenses: Double
    let incomes: Double
    let balance: Double
    let monthName: String
}

struct MoscaBalanceProvider: TimelineProvider {
    private func readData() -> MoscaBalanceEntry {
        let ud = UserDefaults(suiteName: "group.com.mosca.mosca")
        return MoscaBalanceEntry(
            date: Date(),
            expenses:  ud?.double(forKey: "expenses")  ?? 0,
            incomes:   ud?.double(forKey: "incomes")   ?? 0,
            balance:   ud?.double(forKey: "balance")   ?? 0,
            monthName: ud?.string(forKey: "month_name") ?? "Este mes"
        )
    }

    func placeholder(in context: Context) -> MoscaBalanceEntry {
        MoscaBalanceEntry(date: Date(), expenses: 1_200_000, incomes: 3_000_000, balance: 1_800_000, monthName: "Junio")
    }
    func getSnapshot(in context: Context, completion: @escaping (MoscaBalanceEntry) -> Void) {
        completion(readData())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MoscaBalanceEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [readData()], policy: .after(next)))
    }
}

private func formatCOP(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.maximumFractionDigits = 0
    return "$ \(formatter.string(from: NSNumber(value: value)) ?? "0")"
}

private struct MoscaBalanceSmallView: View {
    let entry: MoscaBalanceEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [emerald, emeraldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image("MoscaIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                    Text("Mosca")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Text(entry.monthName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(formatCOP(entry.balance))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(entry.balance >= 0 ? .white : Color(red: 1, green: 0.4, blue: 0.4))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("balance")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MoscaBalanceMediumView: View {
    let entry: MoscaBalanceEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [emerald, emeraldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image("MoscaIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Mosca")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(entry.monthName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                // Balance
                Text(formatCOP(entry.balance))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(entry.balance >= 0 ? .white : Color(red: 1, green: 0.4, blue: 0.4))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Expenses / Incomes row
                HStack(spacing: 0) {
                    _MetricPill(label: "Gastos", value: formatCOP(entry.expenses), color: Color(red: 1, green: 0.4, blue: 0.4))
                    Spacer()
                    _MetricPill(label: "Ingresos", value: formatCOP(entry.incomes), color: Color(red: 0.4, green: 0.87, blue: 0.55))
                }
            }
            .padding(16)
        }
    }
}

private struct _MetricPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

private struct MoscaBalanceEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoscaBalanceEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MoscaBalanceMediumView(entry: entry)
        default:
            MoscaBalanceSmallView(entry: entry)
        }
    }
}

struct MoscaBalanceWidget: Widget {
    let kind = "MoscaBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoscaBalanceProvider()) { entry in
            MoscaBalanceEntryView(entry: entry)
                .widgetBackgroundGradient(
                    LinearGradient(
                        colors: [emerald, emeraldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .configurationDisplayName("Balance del mes")
        .description("Ve tus gastos, ingresos y balance del mes en curso.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── Bundle ────────────────────────────────────────────────────────────────────
@main
struct MoscaWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoscaSmallWidget()
        MoscaMediumWidget()
        MoscaBalanceWidget()
    }
}
