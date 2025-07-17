import UIKit

protocol SortPickerDelegate: AnyObject {
    func sortPickerDidSelect(_ sortOrder: SortOrder)
}

class SortPickerViewController: UIViewController {
    
    weak var delegate: SortPickerDelegate?
    private var currentSortOrder: SortOrder
    
    private lazy var pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sortierung"
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(currentSortOrder: SortOrder) {
        self.currentSortOrder = currentSortOrder
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInitialSelection()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(pickerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(equalToConstant: 220),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            pickerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            pickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            pickerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            pickerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapGesture)
        
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        containerView.addGestureRecognizer(containerTapGesture)
    }
    
    private func setupInitialSelection() {
        if let index = SortOrder.allCases.firstIndex(of: currentSortOrder) {
            pickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }
    
    @objc private func backgroundTapped() {
        dismiss(animated: true)
    }
    
    @objc private func containerTapped() {
        // Verhindert dass der Container tap den background tap auslöst
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Animation für das Erscheinen
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })
    }
}

extension SortPickerViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return SortOrder.allCases.count
    }
}

extension SortPickerViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return SortOrder.allCases[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedSortOrder = SortOrder.allCases[row]
        currentSortOrder = selectedSortOrder
        delegate?.sortPickerDidSelect(selectedSortOrder)
        
        // Kurze Verzögerung für bessere UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.dismiss(animated: true)
        }
    }
}