import XCTest
import CryptoKit

/// The trademarked name of the commercial board game must never appear in the app,
/// its code, or its project files. See CLAUDE.md.
final class NamingTests: XCTestCase {

    /// SHA-256 fingerprints of the forbidden spellings, lowercase, letters only. Stored as
    /// hashes so the name itself never appears in this repository.
    private let forbidden: Set<String> = [
        "ee8f9078c21a5d8225056089a72058814e2a98061489d6e1aff123cce71aa984",
        "b48b8fd8f1d2424d52bede82995ede23992c02a560f5b599c67de9875b47f26a",
        "512b79cfbac42f0a7b1ec877bd73e12439b578acf94e9f711b351f8d2466fb3d"
    ]
    private let lengths = [8, 9]

    func testTrademarkedGameNameIsNotUsedAnywhere() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scanned = ["App", "Sources", "Tests", "docs", "scripts", "project.yml", "Package.swift", "Parjamie.xcodeproj", "CLAUDE.md"]
        let textExtensions: Set<String> = ["swift", "plist", "yml", "pbxproj", "json", "strings", "md", "xcworkspacedata", "html", "css", "sh", "txt"]

        var offenders: [String] = []
        for entry in scanned {
            let url = root.appendingPathComponent(entry)
            let files: [URL]
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                files = enumerator.compactMap { $0 as? URL }
            } else {
                files = [url]
            }
            for file in files where textExtensions.contains(file.pathExtension) {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                if containsForbiddenName(text) {
                    offenders.append(file.path.replacingOccurrences(of: root.path + "/", with: ""))
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "Trademarked game name found in: \(offenders.joined(separator: ", "))")
    }

    func testTheCheckRecognisesAFingerprintedWord() {
        // Built from character codes so no spelling of the name sits in the source.
        let sample = String(decoding: [112, 97, 114, 99, 104, 105, 115, 105], as: UTF8.self)
        XCTAssertTrue(containsForbiddenName("A \(sample.uppercased())-style board"))
        XCTAssertFalse(containsForbiddenName("The race home, for two"))
    }

    /// Slides a window over the letters of the text and compares each window's fingerprint.
    private func containsForbiddenName(_ text: String) -> Bool {
        let letters = Array(text.lowercased().unicodeScalars.filter { ("a"..."z").contains($0) }.map { UInt8($0.value) })
        for length in lengths where letters.count >= length {
            for start in 0...(letters.count - length) {
                let digest = SHA256.hash(data: letters[start..<(start + length)])
                if forbidden.contains(digest.map { String(format: "%02x", $0) }.joined()) { return true }
            }
        }
        return false
    }
}
