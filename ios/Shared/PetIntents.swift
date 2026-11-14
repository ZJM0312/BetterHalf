import AppIntents
import WidgetKit

/// Runs from the interactive pet widget (and in-app), writing straight to the shared store.
struct PetActionIntent: AppIntent {
    static var title: LocalizedStringResource = "和宠物互动"
    static var isDiscoverable = false

    @Parameter(title: "宠物") var petID: String
    @Parameter(title: "动作") var action: String

    init() {}
    init(petID: String, action: PetAction) {
        self.petID = petID
        self.action = action.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard var state = SharedContainer.load(), let a = PetAction(rawValue: action) else { return .result() }
        state.applyPet(a, id: petID)
        try SharedContainer.save(state)
        WidgetCenter.shared.reloadTimelines(ofKind: "PetWidget")
        return .result()
    }
}
