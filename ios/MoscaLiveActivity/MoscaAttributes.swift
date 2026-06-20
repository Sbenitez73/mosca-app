import ActivityKit
import Foundation

// Live Activity data contract — must match what Flutter sends via live_activities plugin
@available(iOS 16.1, *)
public struct MoscaExpenseAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        var amount: String     // formatted e.g. "45,000"
        var category: String   // e.g. "Comida"
        var emoji: String      // e.g. "🍔"
    }
}
