import UIKit

class VersionSelectionViewController: UITableViewController {
    
    private let type: VersionSelectionType
    
    init(type: VersionSelectionType) {
        self.type = type
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
        title = type.title
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return VersionSelectionMethod.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        
        let label = UILabel()
        label.text = type.description
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        
        footerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -8)
        ])
        
        return footerView
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let method = VersionSelectionMethod.allCases[indexPath.row]
        cell.textLabel?.text = method.title
        
        // Get current selection
        let currentMethod = UserDefaults.standard.string(forKey: type.userDefaultsKey) ?? VersionSelectionMethod.askEachTime.rawValue
        
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
        UserDefaults.standard.set(method.rawValue, forKey: type.userDefaultsKey)
        
        // Reload table to update checkmarks
        tableView.reloadData()
        
        // Go back after selection
        navigationController?.popViewController(animated: true)
    }
}