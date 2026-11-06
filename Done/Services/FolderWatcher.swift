import Dispatch
import Foundation

/// Signale les changements d'un dossier : fichier ajouté, remplacé, renommé ou supprimé. Plusieurs
/// changements rapprochés ne donnent qu'un appel. Sans effet hors de macOS.
@MainActor
final class FolderWatcher {
    let folder: URL
    private let onChange: @MainActor () -> Void
    #if canImport(Darwin)
    private var source: DispatchSourceFileSystemObject?
    #endif
    private var pending = false

    init(folder: URL, onChange: @escaping @MainActor () -> Void) {
        self.folder = folder
        self.onChange = onChange
    }

    func start() {
        #if canImport(Darwin)
        guard source == nil else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.schedule() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        #endif
    }

    private func schedule() {
        guard !pending else { return }
        pending = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            pending = false
            onChange()
        }
    }
}
