import AppIntents
import Foundation
import AppKit

struct ToggleMiniRecorderIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notext Recorder"
    static var description = IntentDescription("Start or stop the Notext mini recorder for voice transcription.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .toggleMiniRecorder, object: nil)

        let dialog = IntentDialog(stringLiteral: "Notext recorder toggled")
        return .result(dialog: dialog)
    }
}

enum IntentError: Error, LocalizedError {
    case appNotAvailable
    case serviceNotAvailable

    var errorDescription: String? {
        switch self {
        case .appNotAvailable:
            return "Notext app is not available"
        case .serviceNotAvailable:
            return "Notext recording service is not available"
        }
    }
}
