import Foundation

enum AppConfigFile {
    private static let keyNames = ["api_key", "API_KEY", "talis_api_key", "TALIS_API_KEY"]
    static var configURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(AppIdentity.current.dataDirectoryName).appendingPathComponent("config.yaml")
    }
    static var legacyConfigURLs: [URL] {
        let adjacent = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("config.yaml")
        // /Applications/config.yaml is not an application-owned configuration file.
        var urls = [configURL]
        if adjacent.deletingLastPathComponent().path != "/Applications", adjacent != configURL { urls.append(adjacent) }
        if !AppIdentity.current.isPreview {
            let previous = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Talis-Release/config.yaml")
            if !urls.contains(previous) { urls.append(previous) }
        }
        return urls
    }
    static var modelID: String? { legacyConfigURLs.compactMap { modelID(at: $0) }.first }
    static func modelID(at url: URL) -> String? { value(at: url, keys: ["model", "model_id", "MODEL", "TALIS_MODEL"]) }
    static func apiKey(at url: URL) -> String? {
        guard let value = value(at: url, keys: keyNames), !["YOUR_API_KEY_HERE", "YOUR_API_KEY", "REPLACE_ME"].contains(value.uppercased()) else { return nil }
        return value
    }
    private static func value(at url: URL, keys: [String]) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var values: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("#"), let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) { value = String(value.dropFirst().dropLast()) }
            values[key] = value
        }
        return keys.compactMap { values[$0] }.first { !$0.isEmpty }
    }
    static func removeAPIKey(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let old = try String(contentsOf: url, encoding: .utf8)
        let clean = old.components(separatedBy: .newlines).filter { line in
            guard let colon = line.firstIndex(of: ":"), !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { return true }
            return !keyNames.contains(String(line[..<colon]).trimmingCharacters(in: .whitespaces))
        }.joined(separator: "\n")
        if clean != old {
            try clean.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
}
