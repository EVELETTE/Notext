import AppIntents
import Foundation
import AppKit

struct DismissMiniRecorderIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Notext Recorder"
    static var description = IntentDescription("Dismiss the Notext mini recorder and cancel any active recording.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .dismissMiniRecorder, object: nil)

        let dialog = IntentDialog(stringLiteral: "Notext recorder dismissed")
        return .result(dialog: dialog)
    }
}
