import UIKit
import MobileCoreServices
import Foundation


class AppListViewController: UIViewController {
    
    private var apps: [AppModel] = []
    private var filteredApps: [AppModel] = []
    private var currentSortOrder: SortOrder = .alphabeticalAZ
    private var currentFilterType: FilterType = .all
    private var isSearching: Bool = false
    private var noResultsViewCenterConstraint: NSLayoutConstraint!
    private var isSelectMode: Bool = false
    private var currentSelectionMode: SelectionMode = .block
    private var selectedApps: Set<IndexPath> = []
    private var blockedApps: [String: String] = [:] // bundleId -> originalVersion
    private var spoofedApps: [String: String] = [:] // bundleId -> originalVersion
    var debugMessages: [String] = []
    private var loadingAlert: UIAlertController?
    
    // Empty state views
    private var noResultsImageView: UIImageView!
    private var noResultsTitleLabel: UILabel!
    private var noResultsMessageLabel: UILabel!
    
    // MARK: - Preferences
    private var downloadVersionSelectionMethod: VersionSelectionMethod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "downloadVersionSelectionMethod") ?? VersionSelectionMethod.askEachTime.rawValue
            return VersionSelectionMethod(rawValue: rawValue) ?? .askEachTime
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "downloadVersionSelectionMethod")
        }
    }
    
    private var spoofVersionSelectionMethod: VersionSelectionMethod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "spoofVersionSelectionMethod") ?? VersionSelectionMethod.askEachTime.rawValue
            return VersionSelectionMethod(rawValue: rawValue) ?? .askEachTime
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "spoofVersionSelectionMethod")
        }
    }
    
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search apps or enter bundle ID"
        return searchController
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AppTableViewCell.self, forCellReuseIdentifier: AppTableViewCell.identifier)
        tableView.keyboardDismissMode = .onDrag
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var noResultsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        
        noResultsImageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        noResultsImageView.tintColor = .secondaryLabel
        noResultsImageView.contentMode = .scaleAspectFit
        noResultsImageView.translatesAutoresizingMaskIntoConstraints = false
        
        noResultsTitleLabel = UILabel()
        noResultsTitleLabel.text = "No Results"
        noResultsTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        noResultsTitleLabel.textColor = .secondaryLabel
        noResultsTitleLabel.textAlignment = .center
        noResultsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        noResultsMessageLabel = UILabel()
        noResultsMessageLabel.text = "No apps match your search"
        noResultsMessageLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        noResultsMessageLabel.textColor = .tertiaryLabel
        noResultsMessageLabel.textAlignment = .center
        noResultsMessageLabel.numberOfLines = 0
        noResultsMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(noResultsImageView)
        view.addSubview(noResultsTitleLabel)
        view.addSubview(noResultsMessageLabel)
        
        NSLayoutConstraint.activate([
            noResultsImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResultsImageView.widthAnchor.constraint(equalToConstant: 64),
            noResultsImageView.heightAnchor.constraint(equalToConstant: 64),
            
            noResultsTitleLabel.topAnchor.constraint(equalTo: noResultsImageView.bottomAnchor, constant: 16),
            noResultsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            noResultsTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            noResultsMessageLabel.topAnchor.constraint(equalTo: noResultsTitleLabel.bottomAnchor, constant: 8),
            noResultsMessageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            noResultsMessageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
        
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardNotifications()
        loadBlockedApps()
        loadSpoofedApps()
        loadInstalledApps()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadInstalledApps()
    }
    
    private func setupUI() {
        title = "Apps"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        
        setupNavigationBarButtons()
        
        view.addSubview(tableView)
        view.addSubview(noResultsView)
        
        // Create the top constraint for dynamic adjustment
        noResultsViewCenterConstraint = noResultsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 250)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            noResultsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noResultsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noResultsView.heightAnchor.constraint(equalToConstant: 200),
            
            noResultsViewCenterConstraint
        ])
    }
    
    private func setupNavigationBarButtons() {
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: nil,
            action: nil
        )
        menuButton.menu = createMainMenu()
        
        let downloadButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(downloadAppTapped)
        )
        
        navigationItem.leftBarButtonItem = menuButton
        navigationItem.rightBarButtonItem = downloadButton
    }
    
    private func createMainMenu() -> UIMenu {
        // Sort submenu
        let sortActions = SortOrder.allCases.map { sortOrder in
            UIAction(
                title: sortOrder.title,
                image: nil,
                state: sortOrder == currentSortOrder ? .on : .off
            ) { [weak self] _ in
                self?.currentSortOrder = sortOrder
                self?.sortApps()
                self?.updateMainMenu()
            }
        }
        let sortMenu = UIMenu(title: "Sort", image: UIImage(systemName: "arrow.up.arrow.down"), children: sortActions)
        
        // Filter submenu
        let filterActions = FilterType.allCases.map { filterType in
            UIAction(
                title: filterType.title,
                image: nil,
                state: filterType == currentFilterType ? .on : .off
            ) { [weak self] _ in
                self?.currentFilterType = filterType
                self?.reloadAppList()
                self?.updateMainMenu()
            }
        }
        let filterMenu = UIMenu(title: "Filter", image: UIImage(systemName: "line.horizontal.3.decrease.circle"), children: filterActions)
        
        // Select mode action
        let selectAction = UIAction(
            title: isSelectMode ? "Done" : "Select",
            image: UIImage(systemName: isSelectMode ? "checkmark" : "checkmark.circle")
        ) { [weak self] _ in
            self?.toggleSelectMode()
        }
        
        // Settings action
        let settingsAction = UIAction(
            title: "Settings",
            image: UIImage(systemName: "gear")
        ) { [weak self] _ in
            self?.showSettings()
        }
        
        return UIMenu(title: "", children: [sortMenu, filterMenu, selectAction, settingsAction])
    }
    
    private func updateMainMenu() {
        navigationItem.leftBarButtonItem?.menu = createMainMenu()
    }
    
    
    private func toggleSelectMode() {
        isSelectMode.toggle()
        selectedApps.removeAll()
        
        updateNavigationForSelectMode()
        updateMainMenu()
        
        // Use native iOS editing mode for selection circles
        tableView.setEditing(isSelectMode, animated: true)
        
        // Reload with proper filtering
        reloadAppList()
    }
    
    private func updateNavigationForSelectMode() {
        if isSelectMode {
            // Show Cancel button on left and Done button on right
            let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelSelectingTapped))
            let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneSelectingTapped))
            
            navigationItem.leftBarButtonItem = cancelButton
            navigationItem.rightBarButtonItem = doneButton
            
            // Update title to show selection count
            updateSelectionTitle()
            
            // Show block/unblock toggle buttons in toolbar
            updateSelectionModeButtons()
        } else {
            // Reset to normal state
            title = "Apps"
            
            let menuButton = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: nil,
                action: nil
            )
            menuButton.menu = createMainMenu()
            
            let downloadButton = UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(downloadAppTapped)
            )
            
            navigationItem.leftBarButtonItem = menuButton
            navigationItem.rightBarButtonItem = downloadButton
            
            // Hide toolbar
            navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    private func updateSelectionTitle() {
        let count = selectedApps.count
        if count == 0 {
            title = "Select Apps"
        } else if count == 1 {
            title = "1 App Selected"
        } else {
            title = "\(count) Apps Selected"
        }
    }
    
    private func updateSelectionModeButtons() {
        let blockButton = UIBarButtonItem(
            title: "Block Updates",
            style: currentSelectionMode == .block ? .done : .plain,
            target: self,
            action: #selector(switchToBlockMode)
        )
        
        let unblockButton = UIBarButtonItem(
            title: "Unblock Updates",
            style: currentSelectionMode == .unblock ? .done : .plain,
            target: self,
            action: #selector(switchToUnblockMode)
        )
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [blockButton, flexibleSpace, unblockButton]
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    @objc private func cancelSelectingTapped() {
        // Cancel without applying any changes
        isSelectMode = false
        selectedApps.removeAll()
        updateNavigationForSelectMode()
        updateMainMenu()
        tableView.setEditing(false, animated: true)
        reloadAppList()
    }
    
    @objc private func doneSelectingTapped() {
        // Apply the selected action to all selected apps
        let selectedAppModels = selectedApps.map { indexPath in
            isSearching ? filteredApps[indexPath.row] : apps[indexPath.row]
        }
        
        if currentSelectionMode == .block {
            for app in selectedAppModels {
                blockUpdateForApp(app)
            }
        } else {
            for app in selectedAppModels {
                unblockUpdateForApp(app)
            }
        }
        
        toggleSelectMode()
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    @objc private func switchToBlockMode() {
        currentSelectionMode = .block
        selectedApps.removeAll()
        updateSelectionTitle()
        updateSelectionModeButtons()
        reloadAppList()
    }
    
    @objc private func switchToUnblockMode() {
        currentSelectionMode = .unblock
        selectedApps.removeAll()
        updateSelectionTitle()
        updateSelectionModeButtons()
        reloadAppList()
    }
    
    
    private func debugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        debugMessages.append(logMessage)
        print(logMessage) // Still print to console if available
        
        // Keep only last 100 messages
        if debugMessages.count > 100 {
            debugMessages.removeFirst()
        }
    }
    
    @objc private func showSettings() {
        let settingsController = SettingsViewController(appListController: self)
        let navigationController = UINavigationController(rootViewController: settingsController)
        
        // Full screen modal presentation
        navigationController.modalPresentationStyle = .formSheet
        
        present(navigationController, animated: true)
    }
    
    func showDebugLog() {
        let debugText = debugMessages.isEmpty ? "No debug messages yet" : debugMessages.joined(separator: "\n")
        
        let alertController = UIAlertController(
            title: "Debug Log",
            message: debugText,
            preferredStyle: .alert
        )
        
        // Add copy action
        let copyAction = UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = debugText
        }
        alertController.addAction(copyAction)
        
        // Add clear action
        let clearAction = UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.debugMessages.removeAll()
        }
        alertController.addAction(clearAction)
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
    
    // MARK: - Reset Functions
    
    func resetAllChanges() {
        debugLog("🔄 Starting reset all changes...")
        
        showLoadingDialog(title: "Resetting All Changes", message: "Restoring all apps to original state...")
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { return }
            
            // Reset all spoofed versions first (no UI cache needed)
            self.resetAllVersionsInternal()
            
            // Then unblock all updates (with UI cache rebuild)
            self.unblockAllUpdatesInternal()
            
            DispatchQueue.main.async {
                self.hideLoadingDialog()
                self.showAlert(title: "Reset Complete", message: "All changes have been reset. Your device will respring shortly.")
            }
        }
    }
    
    func unblockAllUpdates() {
        debugLog("🔄 Starting unblock all updates...")
        
        showLoadingDialog(title: "Unblocking Updates", message: "Restoring update capability for all apps...")
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { return }
            
            self.unblockAllUpdatesInternal()
            
            DispatchQueue.main.async {
                self.hideLoadingDialog()
                self.showAlert(title: "Updates Unblocked", message: "All app updates have been unblocked. Your device will respring shortly.")
            }
        }
    }
    
    func resetAllVersions() {
        debugLog("🔄 Starting reset all versions...")
        
        showLoadingDialog(title: "Resetting Versions", message: "Restoring original app versions...")
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { return }
            
            self.resetAllVersionsInternal()
            
            DispatchQueue.main.async {
                self.hideLoadingDialog()
                self.showAlert(title: "Versions Reset", message: "All app versions have been reset to original.")
                self.loadInstalledApps() // Reload to show changes
            }
        }
    }
    
    private func unblockAllUpdatesInternal() {
        guard let helperPath = rootHelperPath() else {
            debugLog("❌ Could not find root helper")
            return
        }
        
        var restoredCount = 0
        
        // Iterate through all blocked apps
        for bundleIdentifier in blockedApps.keys {
            // Find the app bundle path
            if let app = apps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                var stdOut: NSString?
                var stdErr: NSString?
                
                let result = spawnRoot(helperPath, ["restore_updates", app.bundleURL.path], &stdOut, &stdErr)
                
                if result == 0 {
                    restoredCount += 1
                    debugLog("✅ Restored updates for: \(app.name)")
                } else {
                    debugLog("❌ Failed to restore updates for: \(app.name)")
                }
            }
        }
        
        // Clear blocked apps list
        blockedApps.removeAll()
        saveBlockedApps()
        
        debugLog("✅ Restored updates for \(restoredCount) apps")
        
        // Rebuild UI cache
        rebuildUICache()
    }
    
    private func resetAllVersionsInternal() {
        guard let helperPath = rootHelperPath() else {
            debugLog("❌ Could not find root helper")
            return
        }
        
        var restoredCount = 0
        
        // Iterate through all spoofed apps
        for (bundleIdentifier, originalVersion) in spoofedApps {
            // Find the app bundle path
            if let app = apps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                var stdOut: NSString?
                var stdErr: NSString?
                
                let result = spawnRoot(helperPath, ["spoof_app_version", app.bundleURL.path, originalVersion], &stdOut, &stdErr)
                
                if result == 0 {
                    restoredCount += 1
                    debugLog("✅ Restored version for: \(app.name) to \(originalVersion)")
                } else {
                    debugLog("❌ Failed to restore version for: \(app.name)")
                }
            }
        }
        
        // Clear spoofed apps list
        spoofedApps.removeAll()
        saveSpoofedApps()
        
        debugLog("✅ Restored versions for \(restoredCount) apps")
        
        // No UI cache rebuild needed for version changes
    }
    
    
    // MARK: - Update Blocking
    
    private func loadBlockedApps() {
        if let data = UserDefaults.standard.data(forKey: "blockedApps"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            blockedApps = decoded
        }
    }
    
    private func saveBlockedApps() {
        if let encoded = try? JSONEncoder().encode(blockedApps) {
            UserDefaults.standard.set(encoded, forKey: "blockedApps")
        }
    }
    
    private func loadSpoofedApps() {
        if let data = UserDefaults.standard.data(forKey: "spoofedApps"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            spoofedApps = decoded
        }
    }
    
    private func saveSpoofedApps() {
        if let encoded = try? JSONEncoder().encode(spoofedApps) {
            UserDefaults.standard.set(encoded, forKey: "spoofedApps")
        }
    }
    
    private func blockUpdateForApp(_ app: AppModel) {
        debugLog("🔍 Attempting to block updates for: \(app.name)")
        debugLog("📁 Bundle URL: \(app.bundleURL)")
        
        // Store that app is blocked (for UI tracking only)
        blockedApps[app.bundleIdentifier] = "blocked"
        saveBlockedApps()
        
        // Use root helper to block updates by ONLY deleting iTunesMetadata.plist
        let helperPath = rootHelperPath()!
        let appBundlePath = app.bundleURL.path
        
        var stdOut: NSString?
        var stdErr: NSString?
        
        debugLog("🚀 Spawning root helper to block updates")
        let result = spawnRoot(helperPath, ["block_updates", appBundlePath], &stdOut, &stdErr)
        
        if let output = stdOut as String? {
            debugLog("📤 Root helper output: \(output)")
        }
        if let error = stdErr as String? {
            debugLog("❌ Root helper error: \(error)")
        }
        
        if result == 0 {
            debugLog("✅ Successfully blocked updates using root helper")
            
            // Rebuild uicache to make changes effective immediately
            rebuildUICache()
            
            showAlert(title: "Success", message: "Successfully blocked updates for \(app.name)\n\niTunesMetadata.plist has been removed.")
        } else {
            debugLog("❌ Root helper failed with exit code: \(result)")
            showAlert(title: "Error", message: "Failed to block updates. Check debug logs for details.")
        }
    }
    
    private func showBlockedAppInstructions(app: AppModel, originalVersion: String) {
        let message = """
        iOS Container Protection prevents direct modification of installed apps.
        
        To truly block updates for \(app.name):
        
        1. Export the app as IPA using MuffinStore
        2. The IPA will have version modified to 999.999.999
        3. Force reinstall the modified IPA using TrollStore
        
        Current version: \(originalVersion)
        """
        
        let alert = UIAlertController(
            title: "Update Blocking Instructions",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.debugLog("✅ User cancelled update blocking")
        })
        
        alert.addAction(UIAlertAction(title: "Export Modified IPA", style: .default) { _ in
            self.exportModifiedIPA(for: app)
        })
        
        present(alert, animated: true)
    }
    
    private func exportModifiedIPA(for app: AppModel) {
        debugLog("🔧 Attempting to export modified IPA for: \(app.name)")
        
        // Create export directory
        let exportPath = "/var/mobile/Documents/MuffinStore_\(app.bundleIdentifier)_blocked.ipa"
        
        // Show progress
        let progressAlert = UIAlertController(
            title: "Creating Modified IPA",
            message: "Exporting \(app.name) with blocked version...",
            preferredStyle: .alert
        )
        present(progressAlert, animated: true)
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Create temp directory
                let tempDir = NSTemporaryDirectory().appendingFormat("MuffinStore-%@", UUID().uuidString)
                let payloadDir = "\(tempDir)/Payload"
                try FileManager.default.createDirectory(atPath: payloadDir, withIntermediateDirectories: true, attributes: nil)
                
                // Copy app bundle
                let destPath = "\(payloadDir)/\(app.bundleURL.lastPathComponent)"
                try FileManager.default.copyItem(atPath: app.bundleURL.path, toPath: destPath)
                
                // Modify version in the copy
                let infoPlistPath = "\(destPath)/Info.plist"
                if let plist = NSMutableDictionary(contentsOfFile: infoPlistPath) {
                    plist["CFBundleShortVersionString"] = "999.999.999"
                    plist["CFBundleVersion"] = "999999999"
                    
                    if plist.write(toFile: infoPlistPath, atomically: true) {
                        self.debugLog("✅ Modified version in IPA copy")
                        
                        // Create ZIP archive
                        self.createZipArchive(from: tempDir, to: exportPath) { success in
                            DispatchQueue.main.async {
                                progressAlert.dismiss(animated: true) {
                                    if success {
                                        self.showExportSuccess(app: app, ipaPath: exportPath)
                                    } else {
                                        self.showAlert(title: "Export Failed", message: "Could not create IPA archive")
                                    }
                                }
                            }
                            
                            // Cleanup
                            try? FileManager.default.removeItem(atPath: tempDir)
                        }
                    } else {
                        DispatchQueue.main.async {
                            progressAlert.dismiss(animated: true) {
                                self.showAlert(title: "Export Failed", message: "Could not modify app version")
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        progressAlert.dismiss(animated: true) {
                            self.showAlert(title: "Export Failed", message: "Could not read app Info.plist")
                        }
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    progressAlert.dismiss(animated: true) {
                        self.debugLog("❌ IPA export failed: \(error)")
                        self.showAlert(title: "Export Failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func createZipArchive(from sourceDir: String, to destinationPath: String, completion: @escaping (Bool) -> Void) {
        // Use posix_spawn to create zip archive
        let zipPath = "/usr/bin/zip"
        
        zipPath.withCString { zipCString in
            let argv: [UnsafeMutablePointer<CChar>?] = [
                UnsafeMutablePointer(mutating: zipCString),
                UnsafeMutablePointer(mutating: strdup("-r")),
                UnsafeMutablePointer(mutating: strdup(destinationPath)),
                UnsafeMutablePointer(mutating: strdup(".")),
                nil
            ]
            let envp: [UnsafeMutablePointer<CChar>?] = [nil]
            
            var pid: pid_t = 0
            let result = posix_spawn(&pid, zipPath, nil, nil, argv, envp)
            
            if result == 0 {
                // Wait for zip process to complete
                var status: Int32 = 0
                waitpid(pid, &status, 0)
                completion(status == 0)
            } else {
                completion(false)
            }
            
            // Free allocated strings
            for i in 1..<4 {
                free(argv[i])
            }
        }
    }
    
    private func showExportSuccess(app: AppModel, ipaPath: String) {
        let message = """
        Modified IPA created successfully!
        
        Location: \(ipaPath)
        Version: 999.999.999 (update-blocked)
        
        To install:
        1. Open TrollStore
        2. Browse to Documents folder
        3. Install this IPA with "Force Installation"
        4. App will show version 999.999.999 and won't update
        
        Note: This replaces your current app installation.
        """
        
        showAlert(title: "Modified IPA Ready", message: message)
        debugLog("✅ Created modified IPA at: \(ipaPath)")
    }
    
    private func blockUpdateViaTrollStoreMethod(app: AppModel) -> Bool {
        debugLog("🔧 Attempting TrollStore-style direct modification")
        
        // Step 1: Terminate the app first
        terminateApp(bundleIdentifier: app.bundleIdentifier)
        
        // Step 2: Try direct modification with TrollStore-style approach
        return createModifiedAppBundle(originalBundleURL: app.bundleURL, app: app)
    }
    
    private func blockUpdateViaForceReplacement(app: AppModel) -> Bool {
        debugLog("🔧 Attempting force app replacement")
        
        // Step 1: Create backup of original app
        let backupPath = "/var/mobile/Library/MuffinStore/Backups/\(app.bundleIdentifier)"
        let originalPath = app.bundleURL.path
        let backupBundlePath = "\(backupPath)/\(app.bundleURL.lastPathComponent).original"
        
        do {
            try FileManager.default.createDirectory(atPath: backupPath, withIntermediateDirectories: true, attributes: nil)
            
            // Remove existing backup if present
            if FileManager.default.fileExists(atPath: backupBundlePath) {
                try FileManager.default.removeItem(atPath: backupBundlePath)
            }
            
            // Create backup
            try FileManager.default.copyItem(atPath: originalPath, toPath: backupBundlePath)
            debugLog("✅ Created backup at \(backupBundlePath)")
            
            // Step 2: Terminate app
            terminateApp(bundleIdentifier: app.bundleIdentifier)
            
            // Step 3: Modify the app bundle in place
            let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
            guard let plist = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
                debugLog("❌ Could not read Info.plist")
                return false
            }
            
            // Modify version to block updates
            plist["CFBundleShortVersionString"] = "999.999.999"
            plist["CFBundleVersion"] = "999999999"
            
            // Add TrollStore-style marker
            let markerPath = app.bundleURL.appendingPathComponent("_MuffinStore").path
            try "BLOCKED".write(toFile: markerPath, atomically: true, encoding: .utf8)
            
            // Write modified plist
            if plist.write(toFile: infoPlistPath, atomically: true) {
                debugLog("✅ Successfully modified app bundle")
                
                // Fix permissions (like TrollStore does)
                fixAppBundlePermissions(bundleURL: app.bundleURL)
                
                // Refresh Launch Services
                refreshLaunchServices()
                
                return true
            } else {
                debugLog("❌ Failed to write modified plist, restoring backup")
                // Restore from backup if modification failed
                try? FileManager.default.removeItem(atPath: originalPath)
                try? FileManager.default.moveItem(atPath: backupBundlePath, toPath: originalPath)
                return false
            }
        } catch {
            debugLog("❌ Force replacement failed: \(error)")
            return false
        }
    }
    
    private func blockUpdateViaMCMContainer(app: AppModel) -> Bool {
        debugLog("🔧 Attempting container-level manipulation")
        
        // Create container-level configuration files that might be respected by system
        let containerConfigPath = "/var/mobile/Library/MuffinStore/ContainerConfig/\(app.bundleIdentifier).plist"
        
        do {
            try FileManager.default.createDirectory(atPath: (containerConfigPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            
            let containerConfig = [
                "bundleIdentifier": app.bundleIdentifier,
                "updateBlocked": true,
                "containerType": "app",
                "systemApp": true,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            if (containerConfig as NSDictionary).write(toFile: containerConfigPath, atomically: true) {
                debugLog("✅ Created container-level configuration")
                return true
            }
        } catch {
            debugLog("❌ Container manipulation failed: \(error)")
        }
        
        return false
    }
    
    private func blockUpdateViaAppBundleReplacement(app: AppModel) -> Bool {
        debugLog("🔧 Attempting complete app bundle replacement")
        
        let bundlePath = app.bundleURL.path
        let tempBundlePath = "\(bundlePath).modified"
        
        do {
            // Step 1: Create a modified copy of the app bundle
            try FileManager.default.copyItem(atPath: bundlePath, toPath: tempBundlePath)
            debugLog("✅ Created temporary bundle copy")
            
            // Step 2: Modify the copy
            let tempInfoPlistPath = "\(tempBundlePath)/Info.plist"
            guard let plist = NSMutableDictionary(contentsOfFile: tempInfoPlistPath) else {
                try? FileManager.default.removeItem(atPath: tempBundlePath)
                debugLog("❌ Could not read temp Info.plist")
                return false
            }
            
            // Modify version
            plist["CFBundleShortVersionString"] = "999.999.999"
            plist["CFBundleVersion"] = "999999999"
            
            if plist.write(toFile: tempInfoPlistPath, atomically: true) {
                debugLog("✅ Modified temporary bundle")
                
                // Step 3: Terminate app
                terminateApp(bundleIdentifier: app.bundleIdentifier)
                
                // Step 4: Replace original with modified version (atomic operation)
                let backupPath = "\(bundlePath).backup"
                try FileManager.default.moveItem(atPath: bundlePath, toPath: backupPath)
                try FileManager.default.moveItem(atPath: tempBundlePath, toPath: bundlePath)
                
                debugLog("✅ Replaced app bundle atomically")
                
                // Step 5: Fix permissions
                fixAppBundlePermissions(bundleURL: app.bundleURL)
                
                // Step 6: Refresh system
                refreshLaunchServices()
                
                // Clean up backup
                try? FileManager.default.removeItem(atPath: backupPath)
                
                return true
            } else {
                try? FileManager.default.removeItem(atPath: tempBundlePath)
                debugLog("❌ Could not modify temporary bundle")
                return false
            }
        } catch {
            debugLog("❌ App bundle replacement failed: \(error)")
            try? FileManager.default.removeItem(atPath: tempBundlePath)
            return false
        }
    }
    
    private func terminateApp(bundleIdentifier: String) {
        debugLog("🔧 Terminating app: \(bundleIdentifier)")
        
        // Simple approach: Send SIGTERM to process
        killAllPath.withCString { killAllCString in
            bundleIdentifier.withCString { bundleIdCString in
                let argv: [UnsafeMutablePointer<CChar>?] = [
                    UnsafeMutablePointer(mutating: killAllCString),
                    UnsafeMutablePointer(mutating: bundleIdCString),
                    nil
                ]
                let envp: [UnsafeMutablePointer<CChar>?] = [nil]
                
                var pid: pid_t = 0
                let result = posix_spawn(&pid, "/usr/bin/killall", nil, nil, argv, envp)
                debugLog("🔧 Termination result: \(result)")
            }
        }
        
        // Wait a moment for termination
        sleep(1)
    }
    
    private let killAllPath = "/usr/bin/killall"
    
    private func createModifiedAppBundle(originalBundleURL: URL, app: AppModel) -> Bool {
        debugLog("🔧 Creating modified app bundle")
        
        let bundlePath = originalBundleURL.path
        let infoPlistPath = originalBundleURL.appendingPathComponent("Info.plist").path
        
        // Create a backup first
        let backupPath = "/var/mobile/Library/MuffinStore/Backups/\(app.bundleIdentifier)/original"
        let backupDir = (backupPath as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: backupDir, withIntermediateDirectories: true, attributes: nil)
            if FileManager.default.fileExists(atPath: backupPath) {
                try FileManager.default.removeItem(atPath: backupPath)
            }
            try FileManager.default.copyItem(atPath: bundlePath, toPath: backupPath)
            debugLog("✅ Created backup at \(backupPath)")
        } catch {
            debugLog("⚠️ Could not create backup: \(error)")
        }
        
        // Modify the Info.plist
        guard let plist = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
            debugLog("❌ Could not read Info.plist")
            return false
        }
        
        plist["CFBundleShortVersionString"] = "999.999.999"
        plist["CFBundleVersion"] = "999999999"
        
        if plist.write(toFile: infoPlistPath, atomically: true) {
            debugLog("✅ Successfully modified Info.plist")
            
            // Add MuffinStore marker
            let markerPath = originalBundleURL.appendingPathComponent("_MuffinStore").path
            try? "BLOCKED".write(toFile: markerPath, atomically: true, encoding: .utf8)
            
            // Fix permissions
            fixAppBundlePermissions(bundleURL: originalBundleURL)
            
            return true
        } else {
            debugLog("❌ Failed to write Info.plist")
            return false
        }
    }
    
    private func fixAppBundlePermissions(bundleURL: URL) {
        debugLog("🔧 Fixing app bundle permissions")
        
        let bundlePath = bundleURL.path
        
        // Set ownership and permissions like TrollStore does
        chmod(bundlePath, 0o755)
        
        // Recursively fix permissions
        if let enumerator = FileManager.default.enumerator(atPath: bundlePath) {
            while let item = enumerator.nextObject() as? String {
                let itemPath = "\(bundlePath)/\(item)"
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        chmod(itemPath, 0o755)
                    } else {
                        chmod(itemPath, 0o644)
                    }
                }
            }
        }
        
        debugLog("✅ Fixed app bundle permissions")
    }
    
    private func refreshLaunchServices() {
        debugLog("🔧 Refreshing Launch Services")
        
        // Trigger Launch Services refresh
        if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
           let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            _ = workspace.perform(NSSelectorFromString("rebuildApplicationDatabases"))
            debugLog("✅ Triggered Launch Services refresh")
        }
    }
    
    private func blockUpdateViaProcessInterception(app: AppModel) -> Bool {
        debugLog("🔧 Attempting update daemon process interception")
        
        // Create a configuration file that system daemons can check
        let configPath = "/var/mobile/Library/MuffinStore/BlockedApps.plist"
        
        do {
            try FileManager.default.createDirectory(atPath: "/var/mobile/Library/MuffinStore", withIntermediateDirectories: true, attributes: nil)
            
            var blockedAppsConfig = NSMutableDictionary()
            if let existingConfig = NSMutableDictionary(contentsOfFile: configPath) {
                blockedAppsConfig = existingConfig
            }
            
            // Add app to blocked list with detailed info
            blockedAppsConfig[app.bundleIdentifier] = [
                "bundleIdentifier": app.bundleIdentifier,
                "name": app.name,
                "version": app.version,
                "bundlePath": app.bundleURL.path,
                "blocked": true,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            if blockedAppsConfig.write(toFile: configPath, atomically: true) {
                debugLog("✅ Created blocked apps configuration")
                
                // Create a launch daemon configuration
                let launchDaemonPath = "/var/mobile/Library/MuffinStore/com.muffinstore.updateblocker.plist"
                let launchDaemonConfig = [
                    "Label": "com.muffinstore.updateblocker",
                    "ProgramArguments": ["/bin/sh", "-c", "while true; do pkill -f 'appstored\\|softwareupdated\\|mobileassetd'; sleep 60; done"],
                    "RunAtLoad": true,
                    "KeepAlive": true
                ] as [String: Any]
                
                if (launchDaemonConfig as NSDictionary).write(toFile: launchDaemonPath, atomically: true) {
                    debugLog("✅ Created launch daemon configuration")
                    return true
                }
            }
        } catch {
            debugLog("❌ Process interception failed: \(error)")
        }
        
        return false
    }
    
    private func blockUpdateViaAppStoreInterception(app: AppModel) -> Bool {
        debugLog("🔧 Attempting App Store communication interception")
        
        // Create a hosts-like file to block App Store update requests
        let hostsPath = "/var/mobile/Library/MuffinStore/blocked_hosts"
        
        let blockedHosts = [
            "itunes.apple.com",
            "apps.apple.com",
            "ppq.apple.com",
            "osxapps.itunes.apple.com",
            "updates.itunes.apple.com",
            "su.itunes.apple.com"
        ]
        
        let hostsContent = blockedHosts.map { "127.0.0.1 \($0)" }.joined(separator: "\n")
        
        do {
            try hostsContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            debugLog("✅ Created blocked hosts file")
            
            // Create a script to redirect network requests
            let redirectScript = """
            #!/bin/bash
            # Block App Store update requests for blocked apps
            iptables -A OUTPUT -d itunes.apple.com -j DROP
            iptables -A OUTPUT -d apps.apple.com -j DROP
            iptables -A OUTPUT -d ppq.apple.com -j DROP
            """
            
            let scriptPath = "/var/mobile/Library/MuffinStore/block_updates.sh"
            try redirectScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Make script executable
            chmod(scriptPath, 0o755)
            
            debugLog("✅ Created network blocking script")
            return true
        } catch {
            debugLog("❌ App Store interception failed: \(error)")
        }
        
        return false
    }
    
    private func blockUpdateViaNotificationInterception(app: AppModel) -> Bool {
        debugLog("🔧 Attempting system notification interception")
        
        // Create a persistent notification blocker configuration
        let notificationBlockerPath = "/var/mobile/Library/MuffinStore/notification_blocker.plist"
        
        // Use NSNotificationCenter for app-level notifications
        let notificationCenter = NotificationCenter.default
        
        // Register for app lifecycle notifications
        let updateNotifications = [
            "com.apple.LaunchServices.ApplicationRegistered",
            "com.apple.LaunchServices.ApplicationUnregistered",
            "com.apple.mobile.application_installed",
            "com.apple.mobile.application_uninstalled",
            "com.apple.itunesstored.downloads"
        ]
        
        // Create observer for system notifications
        for notification in updateNotifications {
            notificationCenter.addObserver(
                forName: Notification.Name(notification),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.debugLog("🔔 Intercepted notification: \(notification.name)")
                // Here we would block the notification or modify its behavior
            }
        }
        
        debugLog("✅ Registered for system update notifications")
        
        let notificationConfig = [
            "blockedApps": [app.bundleIdentifier],
            "blockedNotifications": updateNotifications,
            "active": true
        ] as [String: Any]
        
        if (notificationConfig as NSDictionary).write(toFile: notificationBlockerPath, atomically: true) {
            debugLog("✅ Created notification blocker configuration")
            return true
        }
        
        return false
    }
    
    private func blockUpdateViaLaunchServicesHook(app: AppModel) -> Bool {
        debugLog("🔧 Attempting Launch Services hook")
        
        // Create a Launch Services override configuration
        let lsOverridePath = "/var/mobile/Library/MuffinStore/ls_override.plist"
        
        var lsOverrideConfig = NSMutableDictionary()
        if let existingConfig = NSMutableDictionary(contentsOfFile: lsOverridePath) {
            lsOverrideConfig = existingConfig
        }
        
        // Add app override information
        lsOverrideConfig[app.bundleIdentifier] = [
            "bundleIdentifier": app.bundleIdentifier,
            "version": "999.999.999",
            "originalVersion": app.version,
            "updateBlocked": true,
            "bundlePath": app.bundleURL.path,
            "LSApplicationCategoryType": "public.app-category.productivity", // Make it look like a system app
            "LSRequiresNativeExecution": true
        ]
        
        if lsOverrideConfig.write(toFile: lsOverridePath, atomically: true) {
            debugLog("✅ Created Launch Services override configuration")
            
            // Try to force Launch Services to rebuild its database
            if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
               let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
                _ = workspace.perform(NSSelectorFromString("rebuildApplicationDatabases"))
                debugLog("✅ Triggered Launch Services database rebuild")
            }
            
            return true
        }
        
        return false
    }
    
    private func blockUpdateViaDirectModification(app: AppModel) -> Bool {
        debugLog("🔧 Attempting direct Info.plist modification with enhanced permissions")
        
        let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
        
        // Try to gain more control over the file
        // Use file descriptor approach for better access
        let fd = open(infoPlistPath, O_RDWR)
        if fd == -1 {
            debugLog("❌ Could not open file descriptor for Info.plist")
            return false
        }
        
        // Try to remove any file locks
        var lock = flock()
        lock.l_type = Int16(F_UNLCK)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        
        if fcntl(fd, F_SETLK, &lock) == -1 {
            debugLog("❌ Could not unlock file")
            close(fd)
            return false
        }
        
        close(fd)
        
        // Now try to modify the plist
        guard let plist = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
            debugLog("❌ Could not read plist after unlock")
            return false
        }
        
        // Set version to high value
        plist["CFBundleShortVersionString"] = "999.999.999"
        plist["CFBundleVersion"] = "999999999"
        
        // Try atomic write to temporary file first
        let tempPath = infoPlistPath + ".tmp"
        if plist.write(toFile: tempPath, atomically: true) {
            // Try to replace the original file
            if Darwin.rename(tempPath, infoPlistPath) == 0 {
                debugLog("✅ Successfully modified Info.plist via temp file")
                return true
            } else {
                debugLog("❌ Could not replace original Info.plist")
                unlink(tempPath)
            }
        }
        
        return false
    }
    
    private func blockUpdateViaiTunesMetadata(app: AppModel) -> Bool {
        debugLog("🔧 Attempting iTunesMetadata.plist modification")
        
        let iTunesMetadataPath = app.bundleURL.appendingPathComponent("iTunesMetadata.plist").path
        
        // Check if iTunesMetadata exists
        if !FileManager.default.fileExists(atPath: iTunesMetadataPath) {
            debugLog("❌ iTunesMetadata.plist not found")
            return false
        }
        
        guard let metadata = NSMutableDictionary(contentsOfFile: iTunesMetadataPath) else {
            debugLog("❌ Could not read iTunesMetadata.plist")
            return false
        }
        
        debugLog("📚 Original iTunesMetadata: \(metadata)")
        
        // Modify version info in iTunes metadata
        metadata["bundleShortVersionString"] = "999.999.999"
        metadata["bundleVersion"] = "999999999"
        
        // Also try to modify the purchase date to make it look like a newer version
        metadata["purchaseDate"] = Date().addingTimeInterval(86400 * 365) // 1 year in future
        
        // Try to write back
        if metadata.write(toFile: iTunesMetadataPath, atomically: true) {
            debugLog("✅ Successfully modified iTunesMetadata.plist")
            return true
        } else {
            debugLog("❌ Failed to write iTunesMetadata.plist")
            return false
        }
    }
    
    private func blockUpdateViaFileSystemTricks(app: AppModel) -> Bool {
        debugLog("🔧 Attempting file system tricks")
        
        let bundlePath = app.bundleURL.path
        let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
        
        // Try to make the entire bundle read-only for system processes
        let result = chmod(bundlePath, 0o755) // rwxr-xr-x
        debugLog("🔧 chmod bundle result: \(result)")
        
        // Try to make Info.plist immutable using chflags
        let chflagsResult = chflags(infoPlistPath, UInt32(UF_IMMUTABLE))
        if chflagsResult == 0 {
            debugLog("✅ Made Info.plist immutable")
            
            // Now try to modify it (this will test if immutable flag works)
            guard let plist = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
                debugLog("❌ Could not read plist after immutable")
                return false
            }
            
            plist["CFBundleShortVersionString"] = "999.999.999"
            plist["CFBundleVersion"] = "999999999"
            
            // Remove immutable flag temporarily
            chflags(infoPlistPath, 0)
            
            if plist.write(toFile: infoPlistPath, atomically: true) {
                // Re-apply immutable flag
                chflags(infoPlistPath, UInt32(UF_IMMUTABLE))
                debugLog("✅ Successfully modified with immutable flag")
                return true
            } else {
                debugLog("❌ Could not write even after removing immutable flag")
                return false
            }
        } else {
            debugLog("❌ Could not set immutable flag: \(errno)")
            return false
        }
    }
    
    private func blockUpdateViaContainerRemapping(app: AppModel) -> Bool {
        debugLog("🔧 Attempting container remapping (Bootstrap technique)")
        
        let bundlePath = app.bundleURL.path
        
        // Create a backup of the original bundle in a system location
        let backupPath = "/var/mobile/Library/MuffinStore/Backups/\(app.bundleIdentifier)"
        
        do {
            try FileManager.default.createDirectory(atPath: backupPath, withIntermediateDirectories: true, attributes: nil)
            
            // Copy the entire bundle to backup location
            let backupBundlePath = "\(backupPath)/\(app.bundleURL.lastPathComponent)"
            try FileManager.default.copyItem(atPath: bundlePath, toPath: backupBundlePath)
            
            // Modify the backup version
            let backupInfoPlistPath = "\(backupBundlePath)/Info.plist"
            guard let backupPlist = NSMutableDictionary(contentsOfFile: backupInfoPlistPath) else {
                debugLog("❌ Could not read backup plist")
                return false
            }
            
            backupPlist["CFBundleShortVersionString"] = "999.999.999"
            backupPlist["CFBundleVersion"] = "999999999"
            
            if backupPlist.write(toFile: backupInfoPlistPath, atomically: true) {
                debugLog("✅ Created modified backup at \(backupBundlePath)")
                
                // Now try to replace the original with the modified backup
                do {
                    try FileManager.default.removeItem(atPath: bundlePath)
                    try FileManager.default.moveItem(atPath: backupBundlePath, toPath: bundlePath)
                    debugLog("✅ Successfully replaced original bundle with modified version")
                    return true
                } catch {
                    debugLog("❌ Could not replace original bundle: \(error)")
                    // Restore original if replacement failed
                    try? FileManager.default.moveItem(atPath: backupBundlePath, toPath: bundlePath)
                    return false
                }
            } else {
                debugLog("❌ Could not modify backup plist")
                return false
            }
        } catch {
            debugLog("❌ Container remapping failed: \(error)")
            return false
        }
    }
    
    private func blockUpdateViaSystemPreferences(app: AppModel) -> Bool {
        debugLog("🔧 Attempting system preference manipulation")
        
        // Create a preference domain for the app to prevent updates
        let preferencesPath = "/var/mobile/Library/Preferences/com.apple.mobile.installation.plist"
        
        guard let prefs = NSMutableDictionary(contentsOfFile: preferencesPath) else {
            debugLog("❌ Could not read installation preferences")
            return false
        }
        
        // Create blocked updates array if it doesn't exist
        let blockedUpdates = prefs["BlockedUpdates"] as? NSMutableArray ?? NSMutableArray()
        
        // Add app to blocked updates
        if !blockedUpdates.contains(app.bundleIdentifier) {
            blockedUpdates.add(app.bundleIdentifier)
            prefs["BlockedUpdates"] = blockedUpdates
            
            if prefs.write(toFile: preferencesPath, atomically: true) {
                debugLog("✅ Added app to blocked updates preference")
                return true
            }
        }
        
        debugLog("❌ Failed to modify installation preferences")
        return false
    }
    
    private func blockUpdateViaMobileInstallation(app: AppModel) -> Bool {
        debugLog("🔧 Attempting Mobile Installation framework manipulation")
        
        // Use MobileInstallation framework to mark app as update-blocked
        // This requires com.apple.private.mobileinstall.allowedSPI entitlement
        
        // Create a mock "system" flag for the app
        let systemAppsPath = "/var/mobile/Library/MobileInstallation/SystemApps.plist"
        
        guard let systemApps = NSMutableDictionary(contentsOfFile: systemAppsPath) else {
            let newSystemApps = NSMutableDictionary()
            newSystemApps[app.bundleIdentifier] = [
                "ApplicationType": "System",
                "UpdateBlocked": true,
                "CFBundleIdentifier": app.bundleIdentifier
            ]
            
            if newSystemApps.write(toFile: systemAppsPath, atomically: true) {
                debugLog("✅ Created system apps preference with blocked app")
                return true
            }
            
            debugLog("❌ Failed to create system apps preference")
            return false
        }
        
        // Add app to system apps list to prevent updates
        systemApps[app.bundleIdentifier] = [
            "ApplicationType": "System",
            "UpdateBlocked": true,
            "CFBundleIdentifier": app.bundleIdentifier
        ]
        
        if systemApps.write(toFile: systemAppsPath, atomically: true) {
            debugLog("✅ Added app to system apps (update blocked)")
            return true
        }
        
        debugLog("❌ Failed to modify system apps preference")
        return false
    }
    
    private func blockUpdateViaLaunchServices(app: AppModel) -> Bool {
        debugLog("🔧 Attempting Launch Services database manipulation")
        
        // Create a copy of the app in a system location (virtually)
        let systemAppPath = "/var/mobile/Library/MobileInstallation/SystemApps/\(app.bundleIdentifier).app"
        
        do {
            try FileManager.default.createDirectory(atPath: systemAppPath, withIntermediateDirectories: true, attributes: nil)
            
            // Create a symlink to the original app
            let originalPath = app.bundleURL.path
            let linkPath = "\(systemAppPath)/\(app.bundleIdentifier)"
            
            do {
                try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: originalPath)
                debugLog("✅ Created system app symlink")
                
                // Force rebuild of Launch Services database using private method
                if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
                   let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
                    _ = workspace.perform(NSSelectorFromString("rebuildApplicationDatabases"))
                    debugLog("✅ Rebuilt Launch Services database")
                }
                
                return true
            } catch {
                debugLog("❌ Failed to create symlink: \(error)")
            }
        } catch {
            debugLog("❌ Failed to create system app directory: \(error)")
        }
        
        debugLog("❌ Failed to manipulate Launch Services database")
        return false
    }
    
    private func blockUpdateViaContainerMetadata(app: AppModel) -> Bool {
        debugLog("🔧 Attempting container metadata manipulation")
        
        // Use Container Manager entitlements to modify app metadata
        let containerPath = app.bundleURL.path
        let metadataPath = "\(containerPath)/.com_apple_mobile_container_manager.plist"
        
        let metadata = NSMutableDictionary()
        metadata["MCMMetadataApplicationIdentifier"] = app.bundleIdentifier
        metadata["MCMMetadataSystemApp"] = true
        metadata["MCMMetadataUpdateBlocked"] = true
        metadata["MCMMetadataUserInitiated"] = false
        
        if metadata.write(toFile: metadataPath, atomically: true) {
            debugLog("✅ Created container metadata to block updates")
            return true
        }
        
        debugLog("❌ Failed to create container metadata")
        return false
    }
    
    private func blockUpdateViaSystemDaemon(app: AppModel) -> Bool {
        debugLog("🔧 Attempting system daemon blocking")
        
        // Create a blocked apps list for system daemons to check
        let blockedAppsPath = "/var/mobile/Library/MobileInstallation/BlockedApps.plist"
        
        var blockedAppsList = NSMutableArray()
        if let existingList = NSMutableArray(contentsOfFile: blockedAppsPath) {
            blockedAppsList = existingList
        }
        
        // Add app to blocked list if not already present
        if !blockedAppsList.contains(app.bundleIdentifier) {
            blockedAppsList.add(app.bundleIdentifier)
            
            if blockedAppsList.write(toFile: blockedAppsPath, atomically: true) {
                debugLog("✅ Added app to system daemon blocked list")
                
                // Kill update-related processes to force refresh
                killUpdateDaemons()
                
                return true
            }
        }
        
        debugLog("❌ Failed to create system daemon blocked list")
        return false
    }
    
    private func killUpdateDaemons() {
        debugLog("🔧 Attempting to kill update daemons")
        
        let updateDaemons = [
            "softwareupdated",
            "mobileassetd",
            "appstored",
            "itunesstored"
        ]
        
        for daemon in updateDaemons {
            // Use spawn instead of system() which is not available on iOS
            let killAllPath = "/usr/bin/killall"
            var pid: pid_t = 0
            
            killAllPath.withCString { killAllCString in
                daemon.withCString { daemonCString in
                    let argv: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: killAllCString),
                        UnsafeMutablePointer(mutating: daemonCString),
                        nil
                    ]
                    let envp: [UnsafeMutablePointer<CChar>?] = [nil]
                    
                    let result = posix_spawn(&pid, killAllPath, nil, nil, argv, envp)
                    debugLog("🔧 Kill \(daemon) result: \(result)")
                }
            }
        }
    }
    
    private func unblockUpdateForApp(_ app: AppModel) {
        debugLog("🔄 Attempting to unblock updates for: \(app.name)")
        
        guard blockedApps[app.bundleIdentifier] != nil else {
            debugLog("❌ No blocked version found for app")
            showAlert(title: "Error", message: "App is not currently blocked")
            return
        }
        
        // Use root helper to restore updates by restoring iTunesMetadata.plist
        let helperPath = rootHelperPath()!
        let appBundlePath = app.bundleURL.path
        
        var stdOut: NSString?
        var stdErr: NSString?
        
        debugLog("🚀 Spawning root helper to restore updates")
        let result = spawnRoot(helperPath, ["restore_updates", appBundlePath], &stdOut, &stdErr)
        
        if let output = stdOut as String? {
            debugLog("📤 Root helper output: \(output)")
        }
        if let error = stdErr as String? {
            debugLog("❌ Root helper error: \(error)")
        }
        
        if result == 0 {
            debugLog("✅ Successfully restored updates using root helper")
            
            // Remove from blocked apps list
            blockedApps.removeValue(forKey: app.bundleIdentifier)
            saveBlockedApps()
            
            // Rebuild uicache to make changes effective immediately
            rebuildUICache()
            
            showAlert(title: "Success", message: "Successfully restored updates for \(app.name)\n\niTunesMetadata.plist has been restored from backup.")
        } else {
            debugLog("❌ Root helper failed with exit code: \(result)")
            showAlert(title: "Error", message: "Failed to restore updates. Check debug logs for details.")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func downloadAppTapped() {
        checkClipboardForAppStoreURL()
    }
    
    private func checkClipboardForAppStoreURL() {
        guard let clipboardText = UIPasteboard.general.string else {
            showDownloadAppAlert()
            return
        }
        
        // Check if clipboard contains App Store URL
        if isAppStoreURL(clipboardText) {
            // Directly download the app from clipboard
            downloadApp(with: clipboardText)
        } else {
            // Show alert for invalid clipboard content
            showInvalidClipboardAlert(with: clipboardText)
        }
    }
    
    private func isAppStoreURL(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        // Check for common App Store URL patterns
        let appStorePatterns = [
            "apps.apple.com",
            "itunes.apple.com",
            "app-store.com",
            "appstore.com"
        ]
        
        // Check if URL contains any App Store domain
        for pattern in appStorePatterns {
            if lowercaseText.contains(pattern) {
                return true
            }
        }
        
        // Check for App Store ID pattern (id followed by numbers)
        if lowercaseText.contains("id") {
            let regex = try? NSRegularExpression(pattern: "id\\d+", options: .caseInsensitive)
            let range = NSRange(location: 0, length: text.count)
            return regex?.firstMatch(in: text, options: [], range: range) != nil
        }
        
        return false
    }
    
    private func showInvalidClipboardAlert(with clipboardText: String) {
        let truncatedText = clipboardText.count > 50 ? String(clipboardText.prefix(50)) + "..." : clipboardText
        
        let alert = UIAlertController(
            title: "Invalid App Store Link",
            message: "The clipboard content is not a valid App Store URL:\n\n\(truncatedText)\n\nWould you like to enter a link manually?",
            preferredStyle: .alert
        )
        
        let enterManuallyAction = UIAlertAction(title: "Enter Manually", style: .default) { [weak self] _ in
            self?.showDownloadAppAlert()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(enterManuallyAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showDownloadAppAlert() {
        let alert = UIAlertController(
            title: "App Link",
            message: "Enter the link to the app you want to download",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "App Link"
            textField.keyboardType = .URL
            
            // Pre-fill with clipboard content if it exists (even if not an App Store URL)
            if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
                textField.text = clipboardText
            }
        }
        
        let downloadAction = UIAlertAction(title: "Download", style: .default) { [weak self] _ in
            guard let link = alert.textFields?.first?.text, !link.isEmpty else { return }
            self?.downloadApp(with: link)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(downloadAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func downloadApp(with link: String) {
        guard let appId = extractAppId(from: link) else {
            showAlert(title: "Error", message: "Invalid link")
            return
        }
        
        showVersionSelectionAlert(for: appId, appName: nil)
    }
    
    private func extractAppId(from link: String) -> Int64? {
        if link.contains("id") {
            let components = link.components(separatedBy: "id")
            guard components.count >= 2 else { return nil }
            let idComponent = components[1].components(separatedBy: "?")[0]
            return Int64(idComponent)
        }
        return nil
    }
    
    private func showVersionSelectionAlert(for appId: Int64, appName: String?) {
        // Check user preference for downloads
        switch downloadVersionSelectionMethod {
        case .appStore:
            fetchVersionsFromServer(for: appId)
            return
        case .manual:
            showManualVersionInput(for: appId)
            return
        case .askEachTime:
            break // Continue with dialog
        }
        
        let title = appName != nil ? "Download \(appName!)" : "Download Version"
        let message = appName != nil ? "Choose how to select the version for \(appName!):" : "Choose how to select the app version:"
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        let appStoreAction = UIAlertAction(title: "App Store", style: .default) { [weak self] _ in
            self?.fetchVersionsFromServer(for: appId)
        }
        
        let manualAction = UIAlertAction(title: "Manual", style: .default) { [weak self] _ in
            self?.showManualVersionInput(for: appId)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(appStoreAction)
        alert.addAction(manualAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showManualVersionInput(for appId: Int64) {
        let alert = UIAlertController(
            title: "Version ID",
            message: "Enter the version ID of the app you want to download",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Version ID"
            textField.keyboardType = .numberPad
        }
        
        let downloadAction = UIAlertAction(title: "Download", style: .default) { [weak self] _ in
            guard let versionIdText = alert.textFields?.first?.text,
                  let versionId = Int64(versionIdText) else { return }
            self?.downloadApp(appId: appId, versionId: versionId)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(downloadAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func fetchVersionsFromServer(for appId: Int64) {
        let serverURL = "https://apis.bilin.eu.org/history/"
        guard let url = URL(string: "\(serverURL)\(appId)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self?.showAlert(title: "Error", message: "No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let versionData = json?["data"] as? [[String: Any]] ?? []
                    
                    if versionData.isEmpty {
                        self?.showAlert(title: "Error", message: "No version IDs, internal error maybe?")
                        return
                    }
                    
                    self?.showVersionListAlert(for: appId, versions: versionData)
                } catch {
                    self?.showAlert(title: "JSON Error", message: error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func showVersionListAlert(for appId: Int64, versions: [[String: Any]], app: AppModel? = nil) {
        debugLog("📋 showVersionListAlert called for appId: \(appId)")
        debugLog("📋 app parameter: \(app?.name ?? "nil")")
        debugLog("📋 currentAppForVersionSelection: \(currentAppForVersionSelection?.name ?? "nil")")
        
        // Get current installed version for reference
        let currentVersionMessage = getCurrentVersionMessage(for: appId)
        debugLog("📋 Generated version message: \(currentVersionMessage)")
        
        let alert = UIAlertController(
            title: "Select Version",
            message: "Choose which version to download\n\n\(currentVersionMessage)",
            preferredStyle: .actionSheet
        )
        
        for version in versions {
            if let bundleVersion = version["bundle_version"] as? String,
               let externalIdentifier = version["external_identifier"] as? Int64 {
                let action = UIAlertAction(title: "Version \(bundleVersion)", style: .default) { [weak self] _ in
                    self?.downloadApp(appId: appId, versionId: externalIdentifier)
                }
                alert.addAction(action)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    // Store the current app being processed for version selection
    private var currentAppForVersionSelection: AppModel?
    
    private func getCurrentVersionMessage(for appId: Int64) -> String {
        debugLog("🔍 getCurrentVersionMessage called with appId: \(appId)")
        debugLog("🔍 currentAppForVersionSelection: \(currentAppForVersionSelection?.name ?? "nil")")
        
        // Use the stored app if available, otherwise try to find it
        let targetApp = currentAppForVersionSelection ?? apps.first { app in
            // Try to match by comparing trackIds if we have API data
            // For now, return the first app as fallback (this is the bug)
            debugLog("🔍 Trying to match app: \(app.name) with appId: \(appId)")
            return false
        }
        
        guard let app = targetApp else {
            debugLog("❌ No target app found, returning Unknown")
            return "Currently installed: Unknown"
        }
        
        debugLog("✅ Found target app: \(app.name), version: \(app.version), bundleId: \(app.bundleIdentifier)")
        
        // Check if app is spoofed
        if let originalVersion = spoofedApps[app.bundleIdentifier] {
            debugLog("🎭 App is spoofed. Original: \(originalVersion), Displayed: \(app.version)")
            return "Currently installed: \(originalVersion) (Original)\nDisplayed version: \(app.version) (Spoofed)"
        } else {
            debugLog("📱 App is not spoofed. Version: \(app.version)")
            return "Currently installed: \(app.version)"
        }
    }
    
    private func showSpoofedAppUpdateWarning(for app: AppModel) {
        let alert = UIAlertController(
            title: "Spoofed App Warning",
            message: "This app (\(app.name)) currently has a spoofed version. After updating/downgrading, the app version will no longer be spoofed and you will need to spoof it again if desired.\n\nDo you want to continue?",
            preferredStyle: .alert
        )
        
        let continueAction = UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.proceedWithDownload(for: app)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(continueAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func proceedWithDownload(for app: AppModel) {
        debugLog("🚀 proceedWithDownload called for app: \(app.name), version: \(app.version)")
        
        // Store the current app for version selection
        currentAppForVersionSelection = app
        debugLog("💾 Stored currentAppForVersionSelection: \(app.name)")
        
        let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let bundleId = infoPlist["CFBundleIdentifier"] as? String else {
            showAlert(title: "Error", message: "Could not read app info")
            return
        }
        
        let url = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&limit=1&media=software"
        guard let requestURL = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self?.showAlert(title: "Error", message: "No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let results = json?["results"] as? [[String: Any]] ?? []
                    
                    if results.isEmpty {
                        self?.showAlert(title: "Error", message: "No results")
                        return
                    }
                    
                    if let trackId = results[0]["trackId"] as? Int64,
                       let appName = results[0]["trackName"] as? String {
                        self?.showVersionSelectionAlert(for: trackId, appName: appName)
                    }
                } catch {
                    self?.showAlert(title: "JSON Error", message: error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func downloadApp(appId: Int64, versionId: Int64) {
        StoreKitDownloader.sharedInstance().downloadApp(withAppId: appId, versionId: versionId)
    }
    
    private func downloadAppShortcut(for app: AppModel) {
        debugLog("🚀 downloadAppShortcut called for app: \(app.name), version: \(app.version)")
        
        // Check if app is spoofed and show warning
        if spoofedApps[app.bundleIdentifier] != nil {
            showSpoofedAppUpdateWarning(for: app)
            return
        }
        
        // Store the current app for version selection
        currentAppForVersionSelection = app
        debugLog("💾 Stored currentAppForVersionSelection: \(app.name)")
        
        let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let bundleId = infoPlist["CFBundleIdentifier"] as? String else {
            showAlert(title: "Error", message: "Could not read app info")
            return
        }
        
        let url = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&limit=1&media=software"
        guard let requestURL = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self?.showAlert(title: "Error", message: "No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let results = json?["results"] as? [[String: Any]] ?? []
                    
                    if results.isEmpty {
                        self?.showAlert(title: "Error", message: "No results")
                        return
                    }
                    
                    if let trackId = results[0]["trackId"] as? Int64,
                       let appName = results[0]["trackName"] as? String {
                        self?.showVersionSelectionAlert(for: trackId, appName: appName)
                    }
                } catch {
                    self?.showAlert(title: "JSON Error", message: error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func sortApps() {
        switch currentSortOrder {
        case .alphabeticalAZ:
            apps.sort { $0.name < $1.name }
            filteredApps.sort { $0.name < $1.name }
        case .alphabeticalZA:
            apps.sort { $0.name > $1.name }
            filteredApps.sort { $0.name > $1.name }
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    private func reloadAppList() {
        if isSelectMode {
            // Filter apps based on current selection mode
            let allApps = apps
            switch currentSelectionMode {
            case .block:
                // Show only apps that are NOT blocked (can be blocked)
                filteredApps = allApps.filter { app in
                    blockedApps[app.bundleIdentifier] == nil
                }
            case .unblock:
                // Show only apps that ARE blocked (can be unblocked)
                filteredApps = allApps.filter { app in
                    blockedApps[app.bundleIdentifier] != nil
                }
            }
            isSearching = true // Use filtered apps
        } else {
            // Normal mode - apply filter based on currentFilterType
            filteredApps = applyCurrentFilter(to: apps)
            isSearching = currentFilterType != .all // Use filtered apps if not showing all
        }
        
        sortApps()
        updateNoResultsView()
    }
    
    private func applyCurrentFilter(to apps: [AppModel]) -> [AppModel] {
        switch currentFilterType {
        case .all:
            return apps
        case .blockedUpdates:
            return apps.filter { app in
                blockedApps[app.bundleIdentifier] != nil
            }
        case .unblockedUpdates:
            return apps.filter { app in
                blockedApps[app.bundleIdentifier] == nil
            }
        case .spoofedVersions:
            return apps.filter { app in
                spoofedApps[app.bundleIdentifier] != nil
            }
        case .unspoofedVersions:
            return apps.filter { app in
                spoofedApps[app.bundleIdentifier] == nil
            }
        }
    }
    
    private func loadInstalledApps() {
        apps.removeAll()
        
        if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
           let defaultWorkspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            
            let enumerateSelector = NSSelectorFromString("enumerateApplicationsOfType:block:")
            if let method = class_getInstanceMethod(object_getClass(defaultWorkspace), enumerateSelector) {
                typealias EnumerateAppsFunction = @convention(c) (AnyObject, Selector, Int, @escaping (AnyObject) -> Void) -> Void
                let enumerateApps = unsafeBitCast(method_getImplementation(method), to: EnumerateAppsFunction.self)
                
                enumerateApps(defaultWorkspace as AnyObject, enumerateSelector, 0) { [weak self] (appProxy: AnyObject) in
                    guard let self = self else { return }
                    
                    if let bundleURL = appProxy.value(forKey: "bundleURL") as? URL,
                       let localizedName = appProxy.value(forKey: "localizedName") as? String,
                       let bundleIdentifier = appProxy.value(forKey: "bundleIdentifier") as? String {
                        
                        let infoPlistPath = bundleURL.appendingPathComponent("Info.plist").path
                        if let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
                           let version = infoPlist["CFBundleShortVersionString"] as? String ?? infoPlist["CFBundleVersion"] as? String {
                            
                            let icon = self.getAppIcon(from: bundleURL)
                            let app = AppModel(
                                name: localizedName,
                                bundleIdentifier: bundleIdentifier,
                                version: version,
                                icon: icon,
                                bundleURL: bundleURL
                            )
                            self.apps.append(app)
                        }
                    }
                }
            }
        }
        
        reloadAppList()
    }
    
    private func getAppIcon(from bundleURL: URL) -> UIImage? {
        let infoPlistPath = bundleURL.appendingPathComponent("Info.plist").path
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else { return nil }
        
        if let icons = infoPlist["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
            
            for iconName in iconFiles.reversed() {
                let iconPath = bundleURL.appendingPathComponent("\(iconName).png").path
                if FileManager.default.fileExists(atPath: iconPath),
                   let iconImage = UIImage(contentsOfFile: iconPath) {
                    return iconImage
                }
                
                let iconPath2x = bundleURL.appendingPathComponent("\(iconName)@2x.png").path
                if FileManager.default.fileExists(atPath: iconPath2x),
                   let iconImage = UIImage(contentsOfFile: iconPath2x) {
                    return iconImage
                }
                
                let iconPath3x = bundleURL.appendingPathComponent("\(iconName)@3x.png").path
                if FileManager.default.fileExists(atPath: iconPath3x),
                   let iconImage = UIImage(contentsOfFile: iconPath3x) {
                    return iconImage
                }
            }
        }
        
        return UIImage(systemName: "app.dashed")
    }
    
    private func updateNoResultsView() {
        let shouldShowNoResults = filteredApps.isEmpty && !apps.isEmpty
        
        if shouldShowNoResults {
            configureEmptyState()
        }
        
        noResultsView.isHidden = !shouldShowNoResults
        // Don't hide the table view, just show the empty state on top
    }
    
    private func configureEmptyState() {
        if searchController.isActive && !searchController.searchBar.text!.isEmpty {
            // Search-specific empty state
            noResultsImageView.image = UIImage(systemName: "magnifyingglass")
            noResultsTitleLabel.text = "No Results"
            noResultsMessageLabel.text = "No apps match your search"
        } else {
            // Filter-specific empty state
            configureFilterEmptyState()
        }
    }
    
    private func configureFilterEmptyState() {
        switch currentFilterType {
        case .all:
            noResultsImageView.image = UIImage(systemName: "apps.iphone")
            noResultsTitleLabel.text = "No Apps Found"
            noResultsMessageLabel.text = "No apps are currently installed"
            
        case .blockedUpdates:
            noResultsImageView.image = UIImage(systemName: "shield.slash")
            noResultsTitleLabel.text = "No Blocked Updates"
            noResultsMessageLabel.text = "You haven't blocked any app updates yet"
            
        case .unblockedUpdates:
            noResultsImageView.image = UIImage(systemName: "shield")
            noResultsTitleLabel.text = "No Allowed Updates"
            noResultsMessageLabel.text = "All your apps have blocked updates"
            
        case .spoofedVersions:
            noResultsImageView.image = UIImage(systemName: "theatermasks")
            noResultsTitleLabel.text = "No Spoofed Versions"
            noResultsMessageLabel.text = "You haven't spoofed any app versions yet"
            
        case .unspoofedVersions:
            noResultsImageView.image = UIImage(systemName: "number.circle")
            noResultsTitleLabel.text = "No Original Versions"
            noResultsMessageLabel.text = "All your apps have spoofed versions"
        }
    }
    
    private func setupKeyboardNotifications() {
        // Keyboard notifications setup
    }
    
    private func showLoadingDialog(title: String, message: String) {
        loadingAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        loadingAlert?.view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: loadingAlert!.view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loadingAlert!.view.topAnchor, constant: 90),
            activityIndicator.bottomAnchor.constraint(lessThanOrEqualTo: loadingAlert!.view.bottomAnchor, constant: -30)
        ])
        
        present(loadingAlert!, animated: true)
    }
    
    private func hideLoadingDialog() {
        guard let alert = loadingAlert else { return }
        alert.dismiss(animated: true) { [weak self] in
            self?.loadingAlert = nil
        }
    }
    
    private func rebuildUICache() {
        debugLog("🔄 Starting UI Cache rebuild with loading dialog...")
        
        // Show loading dialog like TrollStore does
        showLoadingDialog(title: "Rebuilding Icon Cache", message: "Your device will respring when finished. Please do not close the app.")
        
        // Perform operation on background queue
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { return }
            
            guard let helperPath = rootHelperPath() else {
                DispatchQueue.main.async {
                    self.hideLoadingDialog()
                    self.debugLog("❌ Could not find root helper")
                }
                return
            }
            
            var stdOut: NSString?
            var stdErr: NSString?
            
            let result = spawnRoot(helperPath, ["rebuild_uicache"], &stdOut, &stdErr)
            
            if let stdout = stdOut {
                self.debugLog("📤 Root helper output: \(stdout)")
            }
            
            if let stderr = stdErr {
                self.debugLog("🚨 Root helper errors: \(stderr)")
            }
            
            // Return to main queue to update UI
            DispatchQueue.main.async {
                self.hideLoadingDialog()
                
                if result == 0 {
                    self.debugLog("✅ UI Cache rebuild completed successfully")
                } else {
                    self.debugLog("❌ UI Cache rebuild failed with code: \(result)")
                }
            }
        }
    }
    
    func triggerDownloadAction() {
        downloadAppTapped()
    }
    
    func triggerSearchAction() {
        searchController.searchBar.becomeFirstResponder()
    }
    
    private func openApp(bundleIdentifier: String) {
        debugLog("📱 Attempting to open app: \(bundleIdentifier)")
        
        // Method 1: Try URL scheme first
        if let url = URL(string: "\(bundleIdentifier)://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        self.debugLog("✅ Successfully opened app via URL scheme")
                    } else {
                        self.debugLog("❌ Failed to open app via URL scheme")
                        self.openAppViaWorkspace(bundleIdentifier: bundleIdentifier)
                    }
                }
                return
            }
        }
        
        // Method 2: Use LSApplicationWorkspace
        openAppViaWorkspace(bundleIdentifier: bundleIdentifier)
    }
    
    private func openAppViaWorkspace(bundleIdentifier: String) {
        debugLog("🔧 Trying to open app via LSApplicationWorkspace")
        
        if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
           let defaultWorkspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            
            let success = defaultWorkspace.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleIdentifier) != nil
            
            if success {
                debugLog("✅ Successfully opened app via LSApplicationWorkspace")
            } else {
                debugLog("❌ Failed to open app via LSApplicationWorkspace")
                showErrorAlert(message: "Could not open \(bundleIdentifier)")
            }
        } else {
            debugLog("❌ Could not access LSApplicationWorkspace")
            showErrorAlert(message: "Could not open app")
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showVersionSpoofingOptions(for app: AppModel) {
        let infoPlistPath = app.bundleURL.appendingPathComponent("Info.plist").path
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let bundleId = infoPlist["CFBundleIdentifier"] as? String else {
            showAlert(title: "Error", message: "Could not read app info")
            return
        }
        
        // Check user preference for spoofing
        switch spoofVersionSelectionMethod {
        case .appStore:
            fetchVersionsForSpoof(for: app, bundleId: bundleId)
            return
        case .manual:
            showManualVersionSpoofInput(for: app)
            return
        case .askEachTime:
            break // Continue with dialog
        }
        
        let alert = UIAlertController(
            title: "Spoof App Version",
            message: "Choose how to select the version for \(app.name):",
            preferredStyle: .alert
        )
        
        let appStoreAction = UIAlertAction(title: "App Store", style: .default) { _ in
            self.fetchVersionsForSpoof(for: app, bundleId: bundleId)
        }
        
        let manualAction = UIAlertAction(title: "Manual", style: .default) { _ in
            self.showManualVersionSpoofInput(for: app)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(appStoreAction)
        alert.addAction(manualAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showManualVersionSpoofInput(for app: AppModel) {
        let alert = UIAlertController(
            title: "Manual Version Entry",
            message: "Enter the version number to spoof for \(app.name)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "e.g., 1.2.3"
            textField.keyboardType = .decimalPad
        }
        
        alert.addAction(UIAlertAction(title: "Spoof", style: .default) { _ in
            if let version = alert.textFields?.first?.text, !version.isEmpty {
                self.spoofAppVersion(app: app, version: version)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func fetchVersionsForSpoof(for app: AppModel, bundleId: String) {
        // First get the app ID from iTunes
        let url = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&limit=1&media=software"
        guard let requestURL = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self?.showAlert(title: "Error", message: "No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let results = json?["results"] as? [[String: Any]] ?? []
                    
                    if results.isEmpty {
                        self?.showAlert(title: "Error", message: "App not found in App Store")
                        return
                    }
                    
                    if let trackId = results[0]["trackId"] as? Int64 {
                        self?.fetchVersionHistoryForSpoof(for: app, appId: trackId)
                    }
                } catch {
                    self?.showAlert(title: "JSON Error", message: error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func fetchVersionHistoryForSpoof(for app: AppModel, appId: Int64) {
        let serverURL = "https://apis.bilin.eu.org/history/"
        guard let url = URL(string: "\(serverURL)\(appId)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self?.showAlert(title: "Error", message: "No data received from server")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let versionData = json?["data"] as? [[String: Any]] ?? []
                    
                    if versionData.isEmpty {
                        self?.showAlert(title: "Error", message: "No version history found for this app")
                        return
                    }
                    
                    self?.showVersionSpoofListAlert(for: app, versions: versionData)
                } catch {
                    self?.showAlert(title: "JSON Error", message: error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func showVersionSpoofListAlert(for app: AppModel, versions: [[String: Any]]) {
        // Get current version message for reference
        let currentVersionMessage = getCurrentVersionMessageForApp(app: app)
        
        let alert = UIAlertController(
            title: "Select Version to Spoof",
            message: "Choose a version for \(app.name)\n\n\(currentVersionMessage)",
            preferredStyle: .actionSheet
        )
        
        for version in versions {
            if let bundleVersion = version["bundle_version"] as? String {
                let actionTitle = "Version \(bundleVersion)"
                
                alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                    self.spoofAppVersion(app: app, version: bundleVersion)
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func getCurrentVersionMessageForApp(app: AppModel) -> String {
        debugLog("🔍 getCurrentVersionMessageForApp called for app: \(app.name), version: \(app.version)")
        
        // Check if app is spoofed
        if let originalVersion = spoofedApps[app.bundleIdentifier] {
            debugLog("🎭 App is spoofed. Original: \(originalVersion), Displayed: \(app.version)")
            return "Currently installed: \(originalVersion) (Original)\nDisplayed version: \(app.version) (Spoofed)"
        } else {
            debugLog("📱 App is not spoofed. Version: \(app.version)")
            return "Currently installed: \(app.version)"
        }
    }
    
    private func spoofAppVersion(app: AppModel, version: String) {
        debugLog("🎭 Spoofing version for \(app.name) to \(version)")
        
        // Save original version before spoofing
        if spoofedApps[app.bundleIdentifier] == nil {
            spoofedApps[app.bundleIdentifier] = app.version
            saveSpoofedApps()
            debugLog("💾 Saved original version: \(app.version)")
        }
        
        let helperPath = rootHelperPath()!
        let appBundlePath = app.bundleURL.path
        
        var stdOut: NSString?
        var stdErr: NSString?
        
        debugLog("🚀 Spawning root helper to spoof app version")
        let result = spawnRoot(helperPath, ["spoof_app_version", appBundlePath, version], &stdOut, &stdErr)
        
        if let output = stdOut as String? {
            debugLog("📤 Root helper output: \(output)")
        }
        if let error = stdErr as String? {
            debugLog("❌ Root helper error: \(error)")
        }
        
        if result == 0 {
            debugLog("✅ Successfully spoofed app version")
            showAlert(title: "Success", message: "Successfully spoofed app version for \(app.name) to \(version)")
            loadInstalledApps() // Reload apps to show changes
        } else {
            debugLog("❌ Root helper failed with exit code: \(result)")
            showAlert(title: "Error", message: "Failed to spoof app version. Check debug logs for details.")
        }
    }
    
    private func restoreSpoofedAppVersion(app: AppModel) {
        guard let originalVersion = spoofedApps[app.bundleIdentifier] else {
            showAlert(title: "Error", message: "No original version found for \(app.name)")
            return
        }
        
        debugLog("🔄 Restoring original version for \(app.name) from \(app.version) to \(originalVersion)")
        
        let helperPath = rootHelperPath()!
        let appBundlePath = app.bundleURL.path
        
        var stdOut: NSString?
        var stdErr: NSString?
        
        debugLog("🚀 Spawning root helper to restore app version")
        let result = spawnRoot(helperPath, ["spoof_app_version", appBundlePath, originalVersion], &stdOut, &stdErr)
        
        if let output = stdOut as String? {
            debugLog("📤 Root helper output: \(output)")
        }
        if let error = stdErr as String? {
            debugLog("❌ Root helper error: \(error)")
        }
        
        if result == 0 {
            debugLog("✅ Successfully restored app version")
            
            // Remove from spoofed apps
            spoofedApps.removeValue(forKey: app.bundleIdentifier)
            saveSpoofedApps()
            
            showAlert(title: "Success", message: "Successfully restored original version for \(app.name)")
            loadInstalledApps() // Reload apps to show changes
        } else {
            debugLog("❌ Root helper failed with exit code: \(result)")
            showAlert(title: "Error", message: "Failed to restore app version. Check debug logs for details.")
        }
    }
}

// MARK: - UITableViewDataSource
extension AppListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredApps.count : apps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AppTableViewCell.identifier, for: indexPath) as? AppTableViewCell else {
            return UITableViewCell()
        }
        
        let app = isSearching ? filteredApps[indexPath.row] : apps[indexPath.row]
        let isBlocked = blockedApps[app.bundleIdentifier] != nil
        let isSpoofed = spoofedApps[app.bundleIdentifier] != nil
        cell.configure(with: app, isBlocked: isBlocked, isSpoofed: isSpoofed)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AppListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSelectMode {
            // In select mode, track selection (editing mode handles UI)
            selectedApps.insert(indexPath)
            updateSelectionTitle()
        } else {
            // In normal mode, deselect and perform action
            tableView.deselectRow(at: indexPath, animated: true)
            let app = isSearching ? filteredApps[indexPath.row] : apps[indexPath.row]
            downloadAppShortcut(for: app)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isSelectMode {
            selectedApps.remove(indexPath)
            updateSelectionTitle()
        }
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return !isSelectMode
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let app = isSearching ? filteredApps[indexPath.row] : apps[indexPath.row]
        
        let isBlocked = blockedApps[app.bundleIdentifier] != nil
        let blockAction = UIContextualAction(
            style: .normal,
            title: isBlocked ? "Unblock" : "Block"
        ) { [weak self] _, _, completion in
            if isBlocked {
                self?.unblockUpdateForApp(app)
            } else {
                self?.blockUpdateForApp(app)
            }
            completion(true)
        }
        
        blockAction.backgroundColor = isBlocked ? .systemGreen : .systemOrange
        blockAction.image = UIImage(systemName: isBlocked ? "checkmark.shield" : "shield.slash")
        
        let isSpoofed = spoofedApps[app.bundleIdentifier] != nil
        let spoofVersionAction = UIContextualAction(
            style: .normal,
            title: isSpoofed ? "Restore Version" : "Spoof Version"
        ) { [weak self] _, _, completion in
            if isSpoofed {
                self?.restoreSpoofedAppVersion(app: app)
            } else {
                self?.showVersionSpoofingOptions(for: app)
            }
            completion(true)
        }
        
        spoofVersionAction.backgroundColor = isSpoofed ? .systemBlue : .systemPurple
        spoofVersionAction.image = UIImage(systemName: isSpoofed ? "arrow.counterclockwise" : "number.circle")
        
        return UISwipeActionsConfiguration(actions: [blockAction, spoofVersionAction])
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let app = isSearching ? filteredApps[indexPath.row] : apps[indexPath.row]
        let isBlocked = blockedApps[app.bundleIdentifier] != nil
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            // Open App Action
            let openAction = UIAction(
                title: "Open App",
                image: UIImage(systemName: "arrow.up.right.square")
            ) { _ in
                self.openApp(bundleIdentifier: app.bundleIdentifier)
            }
            
            // Update/Downgrade Menu Action
            let updateAction = UIAction(
                title: "Update/Downgrade",
                image: UIImage(systemName: "arrow.down.circle")
            ) { _ in
                self.downloadAppShortcut(for: app)
            }
            
            // Block/Unblock Updates Action
            let blockAction = UIAction(
                title: isBlocked ? "Unblock Updates" : "Block Updates",
                image: UIImage(systemName: isBlocked ? "checkmark.shield" : "shield.slash")
            ) { _ in
                if isBlocked {
                    self.unblockUpdateForApp(app)
                } else {
                    self.blockUpdateForApp(app)
                }
            }
            
            // Spoof/Restore Version Action
            let isSpoofed = self.spoofedApps[app.bundleIdentifier] != nil
            let spoofAction = UIAction(
                title: isSpoofed ? "Restore Original Version" : "Spoof App Version",
                image: UIImage(systemName: isSpoofed ? "arrow.counterclockwise" : "number.circle")
            ) { _ in
                if isSpoofed {
                    self.restoreSpoofedAppVersion(app: app)
                } else {
                    self.showVersionSpoofingOptions(for: app)
                }
            }
            
            // Open in App Store Action
            let appStoreAction = UIAction(
                title: "Open in App Store",
                image: UIImage(systemName: "bag.circle")
            ) { _ in
                self.openAppInAppStore(app: app)
            }
            
            return UIMenu(children: [openAction, appStoreAction, updateAction, blockAction, spoofAction])
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Dismiss keyboard and search when scrolling
        if searchController.isActive {
            searchController.searchBar.resignFirstResponder()
        }
    }
}

// MARK: - UISearchResultsUpdating
extension AppListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        
        if searchText.isEmpty {
            // If no search text, use normal filtering logic
            reloadAppList()
        } else {
            // Apply search filter on top of existing filtering
            let baseApps: [AppModel]
            if isSelectMode {
                // Start with already filtered apps based on selection mode
                switch currentSelectionMode {
                case .block:
                    baseApps = apps.filter { app in
                        blockedApps[app.bundleIdentifier] == nil
                    }
                case .unblock:
                    baseApps = apps.filter { app in
                        blockedApps[app.bundleIdentifier] != nil
                    }
                }
            } else {
                // Normal mode - apply current filter first, then search
                baseApps = applyCurrentFilter(to: apps)
            }
            
            // Apply search filter
            filteredApps = baseApps.filter { app in
                app.name.lowercased().contains(searchText.lowercased()) ||
                app.bundleIdentifier.lowercased().contains(searchText.lowercased())
            }
            isSearching = true
        }
        
        DispatchQueue.main.async {
            self.updateNoResultsView()
            self.tableView.reloadData()
        }
    }
    
    // MARK: - App Store Integration
    
    private func openAppInAppStore(app: AppModel) {
        debugLog("🏪 Opening app in App Store: \(app.name)")
        
        // Try to extract itemID from iTunesMetadata.plist
        if let itemID = extractItemIDFromiTunesMetadata(app: app) {
            debugLog("✅ Found itemID: \(itemID)")
            openAppStoreWithItemID(itemID)
        } else {
            debugLog("❌ Could not find itemID, searching via app name")
            searchAppStoreWithAppName(app.name)
        }
    }
    
    private func extractItemIDFromiTunesMetadata(app: AppModel) -> String? {
        // iTunesMetadata.plist is in the parent directory of the .app bundle
        let iTunesMetadataPath = app.bundleURL.deletingLastPathComponent().appendingPathComponent("iTunesMetadata.plist").path
        
        guard FileManager.default.fileExists(atPath: iTunesMetadataPath) else {
            debugLog("❌ iTunesMetadata.plist not found at: \(iTunesMetadataPath)")
            return nil
        }
        
        guard let metadata = NSDictionary(contentsOfFile: iTunesMetadataPath) else {
            debugLog("❌ Could not read iTunesMetadata.plist")
            return nil
        }
        
        // Try different possible keys for the item ID
        let possibleKeys = ["itemId", "itemID", "playlistId", "trackId", "softwareVersionBundleId", "itemIdentifier"]
        
        for key in possibleKeys {
            if let itemID = metadata[key] {
                let itemIDString = "\(itemID)"
                debugLog("✅ Found itemID '\(itemIDString)' using key: \(key)")
                return itemIDString
            }
        }
        
        debugLog("❌ No itemID found in iTunesMetadata.plist")
        debugLog("📚 Available keys: \(metadata.allKeys)")
        return nil
    }
    
    private func openAppStoreWithItemID(_ itemID: String) {
        let appStoreURL = "https://apps.apple.com/app/id\(itemID)"
        debugLog("🔗 Opening App Store URL: \(appStoreURL)")
        
        if let url = URL(string: appStoreURL) {
            UIApplication.shared.open(url) { success in
                if success {
                    self.debugLog("✅ Successfully opened App Store")
                } else {
                    self.debugLog("❌ Failed to open App Store")
                }
            }
        } else {
            debugLog("❌ Invalid App Store URL")
        }
    }
    
    private func searchAppStoreWithAppName(_ appName: String) {
        // Fallback: search App Store using app name
        let encodedAppName = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appName
        let searchURL = "https://apps.apple.com/search?term=\(encodedAppName)"
        debugLog("🔍 Searching App Store with app name: \(searchURL)")
        
        if let url = URL(string: searchURL) {
            UIApplication.shared.open(url) { success in
                if success {
                    self.debugLog("✅ Successfully opened App Store search")
                } else {
                    self.debugLog("❌ Failed to open App Store search")
                }
            }
        } else {
            debugLog("❌ Invalid App Store search URL")
        }
    }
}

extension AppListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async {
            self.updateNoResultsView()
            self.tableView.reloadData()
        }
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        // Return to normal filtering logic
        reloadAppList()
        DispatchQueue.main.async {
            self.updateNoResultsView()
            self.tableView.reloadData()
        }
    }
}

extension AppListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Return to normal filtering logic
        reloadAppList()
        DispatchQueue.main.async {
            self.updateNoResultsView()
            self.tableView.reloadData()
        }
    }
}