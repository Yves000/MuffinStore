import Foundation

// MARK: - Sort Order
enum SortOrder: CaseIterable {
    case alphabeticalAZ
    case alphabeticalZA
    
    var title: String {
        switch self {
        case .alphabeticalAZ: return "A-Z"
        case .alphabeticalZA: return "Z-A"
        }
    }
}

// MARK: - Filter Type
enum FilterType: CaseIterable {
    case all
    case blockedUpdates
    case unblockedUpdates
    case spoofedVersions
    case unspoofedVersions
    
    var title: String {
        switch self {
        case .all: return "All Apps"
        case .blockedUpdates: return "Update Blocked"
        case .unblockedUpdates: return "Update Allowed"
        case .spoofedVersions: return "Spoofed Versions"
        case .unspoofedVersions: return "Original Versions"
        }
    }
}

// MARK: - Selection Mode
enum SelectionMode {
    case block
    case unblock
    
    var title: String {
        switch self {
        case .block: return "Block"
        case .unblock: return "Unblock"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .block: return "Block Updates"
        case .unblock: return "Unblock Updates"
        }
    }
}

// MARK: - Version Selection
enum VersionSelectionMethod: String, CaseIterable {
    case askEachTime = "ask"
    case appStore = "appstore"
    case manual = "manual"
    
    var title: String {
        switch self {
        case .askEachTime: return "Ask Each Time"
        case .appStore: return "App Store"
        case .manual: return "Manual"
        }
    }
}

enum VersionSelectionType {
    case download
    case spoof
    
    var title: String {
        switch self {
        case .download: return "Download Version Selection"
        case .spoof: return "Spoof Version Selection"
        }
    }
    
    var userDefaultsKey: String {
        switch self {
        case .download: return "downloadVersionSelectionMethod"
        case .spoof: return "spoofVersionSelectionMethod"
        }
    }
    
    var description: String {
        switch self {
        case .download: return "Choose your preferred method for downloading app versions. This will skip the dialog when using the download feature."
        case .spoof: return "Choose your preferred method for spoofing app versions. This will skip the dialog when using the spoof feature."
        }
    }
}