import UIKit

class SettingsViewController: UITableViewController {
    
    private var appListController: AppListViewController?
    
    init(appListController: AppListViewController) {
        self.appListController = appListController
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload preferences section to update the current selection
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }
    
    private func setupUI() {
        title = "Settings"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // Register cell with subtitle style for preferences
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SubtitleCell")
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Preferences
        case 1: return 2 // Reset options
        case 2: return 1 // Debug
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Preferences"
        case 1: return "Reset Options"
        case 2: return "Debug"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Configure your preferred methods for version selection to skip dialogs."
        case 1: return "These actions will reset modifications made by MuffinStore. Use with caution."
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        if indexPath.section == 0 {
            // Use subtitle style for preferences
            cell = UITableViewCell(style: .value1, reuseIdentifier: "SubtitleCell")
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        switch indexPath.section {
        case 0:
            // Preferences
            cell.textLabel?.text = "Version Selection"
            cell.textLabel?.textColor = .label
            cell.imageView?.image = UIImage(systemName: "gear")
            cell.imageView?.tintColor = .systemBlue
            
        case 1:
            // Reset options
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Reset All Changes"
                cell.textLabel?.textColor = .systemRed
                cell.imageView?.image = UIImage(systemName: "arrow.counterclockwise.circle")
                cell.imageView?.tintColor = .systemRed
            case 1:
                cell.textLabel?.text = "Unblock All Updates"
                cell.textLabel?.textColor = .systemOrange
                cell.imageView?.image = UIImage(systemName: "shield.slash")
                cell.imageView?.tintColor = .systemOrange
            default:
                break
            }
        case 2:
            // Debug
            cell.textLabel?.text = "Debug Log"
            cell.textLabel?.textColor = .label
            cell.imageView?.image = UIImage(systemName: "terminal")
            cell.imageView?.tintColor = .systemGray
        default:
            break
        }
        
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    // MARK: - Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            // Preferences
            let versionSelectionVC = VersionSelectionViewController(type: .download)
            navigationController?.pushViewController(versionSelectionVC, animated: true)
        case 1:
            // Reset options
            switch indexPath.row {
            case 0:
                showResetAllConfirmation()
            case 1:
                showUnblockAllConfirmation()
            default:
                break
            }
        case 2:
            // Debug
            let debugLogVC = DebugLogViewController(debugMessages: appListController?.debugMessages ?? [], appListController: appListController)
            navigationController?.pushViewController(debugLogVC, animated: true)
        default:
            break
        }
    }
    
    // MARK: - Reset Actions
    
    private func showResetAllConfirmation() {
        let alert = UIAlertController(
            title: "Reset All Changes",
            message: "This will unblock all app updates. Your device will respring when finished. Please do not close the app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset All", style: .destructive) { _ in
            self.resetAllChanges()
        })
        
        present(alert, animated: true)
    }
    
    private func showUnblockAllConfirmation() {
        let alert = UIAlertController(
            title: "Unblock All Updates",
            message: "This will unblock updates for all apps. Your device will respring when finished. Please do not close the app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unblock All", style: .destructive) { _ in
            self.unblockAllUpdates()
        })
        
        present(alert, animated: true)
    }
    
    
    private func resetAllChanges() {
        appListController?.resetAllChanges()
        dismiss(animated: true)
    }
    
    private func unblockAllUpdates() {
        appListController?.unblockAllUpdates()
        dismiss(animated: true)
    }
    
    
}