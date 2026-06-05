import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

/// Failures from acquiring a downloadable model.
public enum ModelDownloadError: Error, Sendable, Equatable {
    case insufficientStorage(neededBytes: Int, availableBytes: Int)
    case checksumMismatch(expected: String, got: String)
    case downloadFailed(underlyingDescription: String)
}

/// Downloads + verifies a model file from a pinned URL into the on-device models
/// directory. **The one sanctioned outbound network call** (ADR-0012 / privacy
/// posture) — it only fetches the pinned catalogue URL passed in and verifies
/// the bytes against the expected SHA-256.
///
/// Foreground, resumable (HTTP `Range` against a `.part` file), with a
/// free-storage pre-flight. Primitive-param'd so `b0tLlama` needs no `b0tBrain`
/// dependency; the caller (C4) maps an `InferenceModelEntry` to these args.
public actor ModelDownloadManager {
    private let modelsDirectory: URL
    private let session: URLSession
    /// Refuse to start a download unless this much headroom remains beyond the
    /// model size, so we don't fill the disk.
    public static let storageMarginBytes = 250_000_000

    public init(modelsDirectory: URL? = nil, session: URLSession = .shared) {
        self.modelsDirectory = modelsDirectory ?? Self.defaultModelsDirectory
        self.session = session
    }

    /// `Application Support/b0t/models/` — model binaries live here, not in the
    /// markdown brain.
    public static var defaultModelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("b0t/models", isDirectory: true)
    }

    public nonisolated func localURL(filename: String) -> URL {
        modelsDirectory.appendingPathComponent(filename)
    }

    /// A model is present if the final file exists with the expected size.
    public func isDownloaded(filename: String, expectedSize: Int?) -> Bool {
        let url = localURL(filename: filename)
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = (attrs[.size] as? NSNumber)?.intValue
        else { return false }
        if let expectedSize { return size == expectedSize }
        return size > 0
    }

    /// Downloads `filename` from `url`, verifying size + SHA-256. Resumes from a
    /// partial `.part` file via an HTTP `Range` request if one exists. Returns
    /// the verified local URL. No-op (returns immediately) if already present
    /// and checksum-valid.
    public func download(
        from url: URL,
        filename: String,
        expectedSHA256: String,
        expectedSize: Int,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        let dest = localURL(filename: filename)
        if isDownloaded(filename: filename, expectedSize: expectedSize),
            (try? Self.sha256(ofFileAt: dest)) == expectedSHA256
        {
            progress(1.0)
            return dest
        }

        let available = Self.availableCapacityBytes(near: modelsDirectory) ?? Int.max
        guard
            Self.hasSufficientStorage(neededBytes: expectedSize, availableBytes: available)
        else {
            throw ModelDownloadError.insufficientStorage(
                neededBytes: expectedSize, availableBytes: available)
        }
        try FileManager.default.createDirectory(
            at: modelsDirectory, withIntermediateDirectories: true)

        let partURL = dest.appendingPathExtension("part")
        let existing =
            (try? FileManager.default.attributesOfItem(atPath: partURL.path))
            .flatMap { ($0[.size] as? NSNumber)?.intValue } ?? 0

        var request = URLRequest(url: url)
        if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            let total = Self.expectedTotal(
                response: response, alreadyHave: existing, fallback: expectedSize)

            let handle = try Self.openForAppend(partURL, truncatingIfNotResuming: existing == 0)
            defer { try? handle.close() }

            var written = existing
            var buffer = Data()
            buffer.reserveCapacity(1 << 20)
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= (1 << 20) {
                    try handle.write(contentsOf: buffer)
                    written += buffer.count
                    buffer.removeAll(keepingCapacity: true)
                    if total > 0 { progress(min(0.999, Double(written) / Double(total))) }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                written += buffer.count
            }
            try handle.close()
        } catch {
            throw ModelDownloadError.downloadFailed(underlyingDescription: String(describing: error))
        }

        let got = (try? Self.sha256(ofFileAt: partURL)) ?? ""
        guard got == expectedSHA256 else {
            // Leave the .part for a later resume attempt only if it could be a
            // truncation; a hash mismatch on a complete file means corruption —
            // remove so the next attempt re-downloads cleanly.
            try? FileManager.default.removeItem(at: partURL)
            throw ModelDownloadError.checksumMismatch(expected: expectedSHA256, got: got)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: partURL, to: dest)
        progress(1.0)
        return dest
    }

    // MARK: - Pure helpers (unit-tested)

    /// Whether a download should proceed given the model size and free space.
    public static func hasSufficientStorage(
        neededBytes: Int, availableBytes: Int, marginBytes: Int = storageMarginBytes
    ) -> Bool {
        availableBytes >= neededBytes + marginBytes
    }

    /// Total expected bytes for progress: a `206` carries `Content-Range`'s total;
    /// otherwise `alreadyHave + Content-Length`, falling back to the catalogue size.
    static func expectedTotal(response: URLResponse, alreadyHave: Int, fallback: Int) -> Int {
        let len = response.expectedContentLength
        if len > 0 { return alreadyHave + Int(len) }
        return fallback
    }

    /// Streamed SHA-256 (hex) of a file — avoids loading ~1GB into memory.
    static func sha256(ofFileAt url: URL) throws -> String {
        #if canImport(CryptoKit)
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        #else
            throw ModelDownloadError.downloadFailed(underlyingDescription: "CryptoKit unavailable")
        #endif
    }

    /// Free storage capacity near `directory` (probes the nearest existing ancestor).
    /// Consumed by the Stage-D storage line in `AppModelDownloadService.storage()`.
    public static func availableCapacityBytes(near directory: URL) -> Int? {
        // Probe an existing ancestor (the directory may not exist yet).
        var probe = directory
        while !FileManager.default.fileExists(atPath: probe.path),
            probe.pathComponents.count > 1
        {
            probe = probe.deletingLastPathComponent()
        }
        let values = try? probe.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map(Int.init)
    }

    private static func openForAppend(
        _ url: URL, truncatingIfNotResuming truncate: Bool
    ) throws
        -> FileHandle
    {
        if truncate || !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        return handle
    }
}
