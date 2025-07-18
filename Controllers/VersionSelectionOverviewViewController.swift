import UIKit

class VersionSelectionOverviewViewController: UITableViewController {
    
    init() {
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
        title = "Version Selection"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return VersionSelectionMethod.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Download Version Selection"
        case 1: return "Spoof Version Selection"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Choose your preferred method for downloading app versions."
        case 1: return "Choose your preferred method for spoofing app versions."
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let method = VersionSelectionMethod.allCases[indexPath.row]
        cell.textLabel?.text = method.title
        
        // Get current selection based on section
        let userDefaultsKey = indexPath.section == 0 ? "downloadVersionSelectionMethod" : "spoofVersionSelectionMethod"
        let currentMethod = UserDefaults.standard.string(forKey: userDefaultsKey) ?? VersionSelectionMethod.askEachTime.rawValue
        
        // Show checkmark for current selection
        if method.rawValue == currentMethod {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    // MARK: - Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let method = VersionSelectionMethod.allCases[indexPath.row]
        let userDefaultsKey = indexPath.section == 0 ? "downloadVersionSelectionMethod" : "spoofVersionSelectionMethod"
        
        UserDefaults.standard.set(method.rawValue, forKey: userDefaultsKey)
        
        // Reload the section to update checkmarks
        tableView.reloadSections([indexPath.section], with: .none)
    }
}