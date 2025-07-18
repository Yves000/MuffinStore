import UIKit

class DebugLogViewController: UIViewController {
    
    private let textView = UITextView()
    private var debugMessages: [String]
    private weak var appListController: AppListViewController?
    
    init(debugMessages: [String], appListController: AppListViewController? = nil) {
        self.debugMessages = debugMessages
        self.appListController = appListController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Debug Log"
        view.backgroundColor = .systemBackground
        
        // Navigation bar items - both on the right side
        var rightBarButtonItems: [UIBarButtonItem] = []
        
        // Share button
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareDebugLog)
        )
        rightBarButtonItems.append(shareButton)
        
        // Add clear button if we have an app list controller
        if appListController != nil {
            let clearButton = UIBarButtonItem(
                image: UIImage(systemName: "xmark.bin"),
                style: .plain,
                target: self,
                action: #selector(clearDebugLog)
            )
            rightBarButtonItems.append(clearButton)
        }
        
        navigationItem.rightBarButtonItems = rightBarButtonItems
        
        // Setup text view
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.isEditable = false
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content
        updateTextView()
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func shareDebugLog() {
        let debugText = debugMessages.isEmpty ? "No debug messages yet" : debugMessages.joined(separator: "\n")
        
        let activityViewController = UIActivityViewController(
            activityItems: [debugText],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func clearDebugLog() {
        let alert = UIAlertController(
            title: "Clear Debug Log",
            message: "Are you sure you want to clear all debug messages?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.appListController?.debugMessages.removeAll()
            self?.debugMessages.removeAll()
            self?.updateTextView()
        })
        
        present(alert, animated: true)
    }
    
    private func updateTextView() {
        if debugMessages.isEmpty {
            textView.text = "No debug messages yet"
            textView.textColor = .secondaryLabel
        } else {
            textView.text = debugMessages.joined(separator: "\n")
            textView.textColor = .label
        }
    }
}