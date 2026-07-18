import Foundation

enum AppBranding {
    static let displayName = "Y-Keys"
    static let bundleIdentifier = "com.lixingchen.YKeys"
    static let teamIdentifier = "A94225N8T5"
    static let installedApplicationURL = URL(fileURLWithPath: "/Applications/Y-Keys.app", isDirectory: true)
    static let installedApplicationPath = installedApplicationURL.path
    static let repositoryURL = URL(string: "https://github.com/Rainchen537/Y-Keys")!
}
