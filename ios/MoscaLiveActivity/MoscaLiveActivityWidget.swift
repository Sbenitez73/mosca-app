import ActivityKit
import SwiftUI
import WidgetKit

// ──────────────────────────────────────────────────────────────────────────────
// Dynamic Island + Lock Screen Live Activity for Mosca
// Setup in Xcode:
//   1. File > New > Target > Widget Extension (name: MoscaLiveActivity)
//   2. Add this file + MoscaAttributes.swift to the extension target
//   3. Add App Group "group.com.mosca.mosca" to both Runner and this extension
//   4. In Runner's Info.plist add NSSupportsLiveActivities = YES
// ──────────────────────────────────────────────────────────────────────────────

struct MoscaLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MoscaExpenseAttributes.self) { context in
            // Lock Screen banner
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (user long-presses Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                        .font(.title2)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(context.state.amount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(context.state.category)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Registrando gasto en Mosca...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                // Compact left — emoji
                Text(context.state.emoji)
                    .font(.body)
            } compactTrailing: {
                // Compact right — amount
                Text("$\(context.state.amount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.green)
            } minimal: {
                // Minimal (two activities competing)
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.green)
            }
            .widgetURL(URL(string: "mosca://quick-add"))
            .keylineTint(.green)
        }
    }
}

struct LockScreenView: View {
    let state: MoscaExpenseAttributes.State

    var body: some View {
        HStack(spacing: 16) {
            Text(state.emoji)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(state.amount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(state.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
                .font(.title2)
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.04, green: 0.49, blue: 0.29))
        .activitySystemActionForegroundColor(.white)
    }
}

@main
struct MoscaLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MoscaLiveActivityWidget()
    }
}
