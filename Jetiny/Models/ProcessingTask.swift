import Foundation

enum ProcessingStatus: Equatable, Sendable {
    case pending
    case processing(progress: Double)
    case completed(result: ProcessingResult)
    case failed(error: String)
    case cancelled

    var isCompleted: Bool {
        switch self {
        case .completed: return true
        default: return false
        }
    }

    var isFailed: Bool {
        switch self {
        case .failed: return true
        default: return false
        }
    }
}

@Observable
@MainActor
final class ProcessingTask: Identifiable {
    let id: UUID = UUID()
    let mediaItem: MediaItem
    var status: ProcessingStatus = .pending

    init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
    }

    var progress: Double {
        switch status {
        case .processing(let p): return p
        case .completed: return 1.0
        default: return 0.0
        }
    }

    var result: ProcessingResult? {
        switch status {
        case .completed(let r): return r
        default: return nil
        }
    }

    var errorMessage: String? {
        switch status {
        case .failed(let e): return e
        default: return nil
        }
    }
}
