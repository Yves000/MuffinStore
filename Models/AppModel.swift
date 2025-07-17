import UIKit

struct AppModel {
    let name: String
    let bundleIdentifier: String
    let version: String
    let icon: UIImage?
    let bundleURL: URL
}

struct AppVersionInfo {
    let bundleVersion: String
    let externalIdentifier: Int64
}