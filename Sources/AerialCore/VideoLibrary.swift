import Foundation
import os

/// The Aerial videos macOS keeps on disk, one `<assetID>.mov` per Aerial.
/// An Aerial that isn't downloaded shows as the macOS default wallpaper, and macOS
/// doesn't fetch it by itself, so the app downloads missing videos of the chosen set.
public struct VideoLibrary: Sendable {
    let paths: Paths

    public init(paths: Paths = .live) {
        self.paths = paths
    }

    public func isDownloaded(_ aerial: Aerial) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: file(for: aerial).path)[.size] as? Int) ?? 0
        return size > 0
    }

    public func missing(in set: AerialSet) -> [Aerial] {
        set.aerials.filter { !isDownloaded($0) }
    }

    /// Bytes still to download for a set, from the server's Content-Length.
    public func downloadSize(of aerials: [Aerial]) async -> Int64 {
        await withTaskGroup(of: Int64.self) { group in
            for aerial in aerials {
                guard let url = aerial.videoURL else { continue }
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    let response = try? await URLSession.shared.data(for: request).1
                    return max(response?.expectedContentLength ?? 0, 0)
                }
            }
            return await group.reduce(0, +)
        }
    }

    /// Downloads one video. `progress` gets the fraction done, 0...1.
    ///
    /// Streams into a file of our own rather than using a download task: an async download
    /// task never reports progress, and a cancelled one leaves its partial file behind.
    public func download(_ aerial: Aerial, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        guard let url = aerial.videoURL else {
            throw AerialError("\(aerial.label) has no download link in the manifest.")
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: paths.partialDownloads, withIntermediateDirectories: true)
        let partial = paths.partialDownloads.appendingPathComponent("\(aerial.id).mov")
        defer { try? fileManager.removeItem(at: partial) }

        let writer = try DownloadWriter(file: partial, progress: progress)
        let session = URLSession(configuration: .default, delegate: writer, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            try await writer.run(session.dataTask(with: url))
        } catch DownloadWriter.Failure.status {
            throw AerialError("Downloading \(aerial.label) failed.")
        }

        let destination = file(for: aerial)
        try fileManager.createDirectory(at: paths.videos, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: partial, to: destination)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    private func file(for aerial: Aerial) -> URL {
        paths.videos.appendingPathComponent("\(aerial.id).mov")
    }
}

/// Writes a data task's response to a file, reporting progress in whole percents.
private final class DownloadWriter: NSObject, URLSessionDataDelegate, Sendable {
    enum Failure: Error { case status }

    private struct State {
        var handle: FileHandle
        var continuation: CheckedContinuation<Void, Error>?
        var task: URLSessionTask?
        var cancelled = false
        var failure: Error?
        var expected: Int64 = 0
        var received: Int64 = 0
        var percent = -1
    }

    private let state: OSAllocatedUnfairLock<State>
    private let progress: @Sendable (Double) -> Void

    init(file: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        FileManager.default.createFile(atPath: file.path, contents: nil)
        state = OSAllocatedUnfairLock(uncheckedState: State(handle: try FileHandle(forWritingTo: file)))
        self.progress = progress
    }

    func run(_ task: URLSessionDataTask) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let cancelled = state.withLockUnchecked { state in
                    state.continuation = continuation
                    state.task = task
                    return state.cancelled
                }
                cancelled ? task.cancel() : task.resume()
                if cancelled { finish(CancellationError()) }
            }
        } onCancel: {
            let task = state.withLockUnchecked { state in
                state.cancelled = true
                return state.task
            }
            task?.cancel()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            state.withLockUnchecked { $0.failure = Failure.status }
            return .cancel
        }
        state.withLockUnchecked { $0.expected = response.expectedContentLength }
        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let fraction: Double? = state.withLockUnchecked { state in
            do {
                try state.handle.write(contentsOf: data)
            } catch {
                state.failure = error
                dataTask.cancel()
                return nil
            }
            state.received += Int64(data.count)
            guard state.expected > 0 else { return nil }
            let fraction = Double(state.received) / Double(state.expected)
            let percent = Int(fraction * 100)
            guard percent != state.percent else { return nil }
            state.percent = percent
            return fraction
        }
        if let fraction { progress(fraction) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(error)
    }

    private func finish(_ error: Error?) {
        let (continuation, result) = state.withLockUnchecked { state in
            defer { state.continuation = nil }
            try? state.handle.close()
            let result: Error? = state.failure ?? (state.cancelled ? CancellationError() : error)
            return (state.continuation, result)
        }
        if let result { continuation?.resume(throwing: result) } else { continuation?.resume() }
    }
}
