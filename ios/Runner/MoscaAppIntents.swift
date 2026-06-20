import AppIntents
import Foundation

// Action Button shortcut — iPhone 15 Pro / 16 Pro+
// In Settings > Action Button, select "Shortcut" and choose "Add Expense in Mosca"
@available(iOS 16.0, *)
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense in Mosca"
    static var description = IntentDescription(
        "Opens Mosca directly to the quick-add expense screen"
    )
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Deep link handled in AppDelegate via URL scheme mosca://quick-add
        return .result()
    }
}

@available(iOS 16.0, *)
struct MoscaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "New expense in \(.applicationName)",
                "Register expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
