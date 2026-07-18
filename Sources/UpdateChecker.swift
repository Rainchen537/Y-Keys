import Foundation

enum UpdateCheckStatus {
    case upToDate(version: String)
    case available(version: String)
    case failed(message: String)
}

final class UpdateChecker {
    private struct Release: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(completion: @escaping (UpdateCheckStatus) -> Void) {
        let url = URL(string: "https://api.github.com/repos/Rainchen537/Y-Keys/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("Y-Keys/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { data, response, error in
            let status: UpdateCheckStatus
            if let error {
                status = .failed(message: error.localizedDescription)
            } else if
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                let data
            {
                do {
                    let release = try JSONDecoder().decode(Release.self, from: data)
                    let latestVersion = Self.displayVersion(from: release.tagName)
                    if let isNewer = Self.isVersion(latestVersion, newerThan: self.currentVersion) {
                        status = isNewer
                            ? .available(version: latestVersion)
                            : .upToDate(version: self.currentVersion)
                    } else {
                        status = .failed(message: "无法识别版本号：\(release.tagName)。")
                    }
                } catch {
                    status = .failed(message: "无法解析 GitHub Release 信息。")
                }
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                status = .failed(message: code == 0 ? "无法连接 GitHub。" : "GitHub 返回错误（\(code)）。")
            }

            DispatchQueue.main.async {
                completion(status)
            }
        }.resume()
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private static func displayVersion(from tagName: String) -> String {
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = trimmedTag.first, firstCharacter == "v" || firstCharacter == "V" else {
            return trimmedTag
        }
        return String(trimmedTag.dropFirst())
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool? {
        guard
            let candidateParts = numericVersionComponents(from: candidate),
            let currentParts = numericVersionComponents(from: current)
        else {
            return nil
        }
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }

        return false
    }

    private static func numericVersionComponents(from rawValue: String) -> [Int]? {
        let value = displayVersion(from: rawValue)
        guard value.first?.isNumber == true else { return nil }

        let numericPrefix = value.prefix { character in
            character.isNumber || character == "."
        }
        let segments = numericPrefix.split(separator: ".", omittingEmptySubsequences: false)
        guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty }) else { return nil }

        let components = segments.compactMap { Int($0) }
        return components.count == segments.count ? components : nil
    }
}
