import XCTest

@testable import b0tLlama

#if canImport(CryptoKit)
    import CryptoKit
#endif

/// Host unit tests for the download manager's pure logic (pre-flight, checksum,
/// path/size bookkeeping). The actual network fetch is in the gated live test.
final class ModelDownloadManagerTests: XCTestCase {
    func test_hasSufficientStorage_respectsMargin() {
        XCTAssertTrue(
            ModelDownloadManager.hasSufficientStorage(
                neededBytes: 100, availableBytes: 100 + ModelDownloadManager.storageMarginBytes))
        XCTAssertFalse(
            ModelDownloadManager.hasSufficientStorage(neededBytes: 100, availableBytes: 100))
        XCTAssertTrue(
            ModelDownloadManager.hasSufficientStorage(
                neededBytes: 100, availableBytes: 500, marginBytes: 100))
        XCTAssertFalse(
            ModelDownloadManager.hasSufficientStorage(
                neededBytes: 100, availableBytes: 150, marginBytes: 100))
    }

    func test_sha256_streamedMatchesDirectHash() throws {
        #if canImport(CryptoKit)
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("b0t-sha-\(UUID().uuidString)")
            let data = Data("the quick brown fox jumps over the lazy dog\n".utf8)
            try data.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }

            let streamed = try ModelDownloadManager.sha256(ofFileAt: tmp)
            let direct = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(streamed, direct)
            XCTAssertEqual(streamed.count, 64)
        #endif
    }

    func test_isDownloaded_checksExistenceAndSize() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("b0t-md-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mgr = ModelDownloadManager(modelsDirectory: dir)
        let none = await mgr.isDownloaded(filename: "m.gguf", expectedSize: 5)
        XCTAssertFalse(none)

        try Data([1, 2, 3, 4, 5]).write(to: dir.appendingPathComponent("m.gguf"))
        let exact = await mgr.isDownloaded(filename: "m.gguf", expectedSize: 5)
        let wrong = await mgr.isDownloaded(filename: "m.gguf", expectedSize: 99)
        let anySize = await mgr.isDownloaded(filename: "m.gguf", expectedSize: nil)
        XCTAssertTrue(exact)
        XCTAssertFalse(wrong)
        XCTAssertTrue(anySize)
    }

    func test_localURL_composesUnderModelsDirectory() {
        let mgr = ModelDownloadManager(modelsDirectory: URL(fileURLWithPath: "/tmp/m", isDirectory: true))
        XCTAssertEqual(mgr.localURL(filename: "x.gguf").path, "/tmp/m/x.gguf")
    }
}
