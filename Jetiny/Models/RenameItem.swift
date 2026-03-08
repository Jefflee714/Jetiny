import Foundation

struct RenameItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let fileName: String
    let nameWithoutExtension: String
    let fileExtension: String
    let fileSize: Int64
    let directoryURL: URL

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension
        self.nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        self.directoryURL = url.deletingLastPathComponent()
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        self.fileSize = Int64(resourceValues?.fileSize ?? 0)
    }

    // Hashable based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RenameItem, rhs: RenameItem) -> Bool {
        lhs.id == rhs.id
    }
}
