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
    
    private func setupUI() {
        title = "Settings"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Reset options
        case 1: return 1 // Debug
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Reset Options"
        case 1: return "Debug"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "These actions will reset modifications made by MuffinStore. Use with caution."
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        switch indexPath.section {
        case 0:
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
            case 2:
                cell.textLabel?.text = "Reset All Versions"
                cell.textLabel?.textColor = .systemBlue
                cell.imageView?.image = UIImage(systemName: "number.circle")
                cell.imageView?.tintColor = .systemBlue
            default:
                break
            }
        case 1:
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
            switch indexPath.row {
            case 0:
                showResetAllConfirmation()
            case 1:
                showUnblockAllConfirmation()
            case 2:
                showResetVersionsConfirmation()
            default:
                break
            }
        case 1:
            showDebugLog()
        default:
            break
        }
    }
    
    // MARK: - Reset Actions
    
    private func showResetAllConfirmation() {
        let alert = UIAlertController(
            title: "Reset All Changes",
            message: "This will unblock all app updates and reset all spoofed versions to their original state. Your device will respring when finished.",
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
            message: "This will unblock updates for all apps. Your device will respring when finished.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unblock All", style: .destructive) { _ in
            self.unblockAllUpdates()
        })
        
        present(alert, animated: true)
    }
    
    private func showResetVersionsConfirmation() {
        let alert = UIAlertController(
            title: "Reset All Versions",
            message: "This will reset all spoofed app versions to their original state. No respring required.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset Versions", style: .destructive) { _ in
            self.resetAllVersions()
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
    
    private func resetAllVersions() {
        appListController?.resetAllVersions()
        dismiss(animated: true)
    }
    
    private func showDebugLog() {
        guard let appListController = appListController else { return }
        
        let debugText = appListController.debugMessages.isEmpty ? "No debug messages yet" : appListController.debugMessages.joined(separator: "\n")
        
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
            self?.appListController?.debugMessages.removeAll()
        }
        alertController.addAction(clearAction)
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}