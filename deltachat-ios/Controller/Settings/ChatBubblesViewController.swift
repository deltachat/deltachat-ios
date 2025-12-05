import UIKit
import DcCore

class ChatBubblesViewController: UITableViewController {
    
    private let dcContext: DcContext
    
    private enum CellTags: Int {
        case senderBubble
        case receiverBubble
        case cornerRadius
        case resetDefaults
    }
    
    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
        
        init(headerTitle: String? = nil, footerTitle: String? = nil, cells: [UITableViewCell]) {
            self.headerTitle = headerTitle
            self.footerTitle = footerTitle
            self.cells = cells
        }
    }
    
    // MARK: - Cells
    
    private lazy var senderBubbleCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.senderBubble.rawValue
        cell.textLabel?.text = String.localized("pref_sender_bubble_color")
        cell.detailTextLabel?.text = String.localized("tap_to_change")
        cell.accessoryType = .disclosureIndicator
        
        let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        colorPreview.layer.cornerRadius = 15
        colorPreview.backgroundColor = getSenderBubbleColor()
        colorPreview.layer.borderWidth = 1
        colorPreview.layer.borderColor = UIColor.systemGray4.cgColor
        cell.accessoryView = colorPreview
        
        return cell
    }()
    
    private lazy var receiverBubbleCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.receiverBubble.rawValue
        cell.textLabel?.text = String.localized("pref_receiver_bubble_color")
        cell.detailTextLabel?.text = String.localized("tap_to_change")
        cell.accessoryType = .disclosureIndicator
        
        let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        colorPreview.layer.cornerRadius = 15
        colorPreview.backgroundColor = getReceiverBubbleColor()
        colorPreview.layer.borderWidth = 1
        colorPreview.layer.borderColor = UIColor.systemGray4.cgColor
        cell.accessoryView = colorPreview
        
        return cell
    }()
    
    private lazy var cornerRadiusCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.cornerRadius.rawValue
        cell.selectionStyle = .none
        
        let containerStack = UIStackView()
        containerStack.axis = .vertical
        containerStack.spacing = 12
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Label and value stack
        let labelStack = UIStackView()
        labelStack.axis = .horizontal
        labelStack.distribution = .equalSpacing
        
        let titleLabel = UILabel()
        titleLabel.text = String.localized("pref_bubble_corner_radius")
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        
        cornerRadiusValueLabel.text = String(format: "%.0f", getCurrentCornerRadius())
        cornerRadiusValueLabel.font = UIFont.preferredFont(forTextStyle: .body)
        cornerRadiusValueLabel.textColor = .secondaryLabel
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(cornerRadiusValueLabel)
        
        // Slider
        cornerRadiusSlider.minimumValue = 0
        cornerRadiusSlider.maximumValue = 30
        cornerRadiusSlider.value = getCurrentCornerRadius()
        cornerRadiusSlider.addTarget(self, action: #selector(cornerRadiusChanged(_:)), for: .valueChanged)
        
        // Preview bubbles stack
        let previewStack = UIStackView()
        previewStack.axis = .vertical
        previewStack.spacing = 8
        previewStack.alignment = .fill
        
        // Sender bubble preview (right aligned)
        let senderContainer = UIView()
        senderBubblePreview.backgroundColor = getSenderBubbleColor()
        senderBubblePreview.translatesAutoresizingMaskIntoConstraints = false
        senderContainer.addSubview(senderBubblePreview)
        
        let senderLabel = UILabel()
        senderLabel.text = String.localized("pref_sender_bubble_preview")
        senderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        senderLabel.textColor = .label
        senderLabel.numberOfLines = 0
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        senderBubblePreview.addSubview(senderLabel)
        
        NSLayoutConstraint.activate([
            senderBubblePreview.trailingAnchor.constraint(equalTo: senderContainer.trailingAnchor),
            senderBubblePreview.topAnchor.constraint(equalTo: senderContainer.topAnchor),
            senderBubblePreview.bottomAnchor.constraint(equalTo: senderContainer.bottomAnchor),
            senderBubblePreview.widthAnchor.constraint(lessThanOrEqualTo: senderContainer.widthAnchor, multiplier: 0.7),
            senderLabel.leadingAnchor.constraint(equalTo: senderBubblePreview.leadingAnchor, constant: 12),
            senderLabel.trailingAnchor.constraint(equalTo: senderBubblePreview.trailingAnchor, constant: -12),
            senderLabel.topAnchor.constraint(equalTo: senderBubblePreview.topAnchor, constant: 8),
            senderLabel.bottomAnchor.constraint(equalTo: senderBubblePreview.bottomAnchor, constant: -8)
        ])
        
        // Receiver bubble preview (left aligned)
        let receiverContainer = UIView()
        receiverBubblePreview.backgroundColor = getReceiverBubbleColor()
        receiverBubblePreview.translatesAutoresizingMaskIntoConstraints = false
        receiverContainer.addSubview(receiverBubblePreview)
        
        let receiverLabel = UILabel()
        receiverLabel.text = String.localized("pref_receiver_bubble_preview")
        receiverLabel.font = UIFont.preferredFont(forTextStyle: .body)
        receiverLabel.textColor = .label
        receiverLabel.numberOfLines = 0
        receiverLabel.translatesAutoresizingMaskIntoConstraints = false
        receiverBubblePreview.addSubview(receiverLabel)
        
        NSLayoutConstraint.activate([
            receiverBubblePreview.leadingAnchor.constraint(equalTo: receiverContainer.leadingAnchor),
            receiverBubblePreview.topAnchor.constraint(equalTo: receiverContainer.topAnchor),
            receiverBubblePreview.bottomAnchor.constraint(equalTo: receiverContainer.bottomAnchor),
            receiverBubblePreview.widthAnchor.constraint(lessThanOrEqualTo: receiverContainer.widthAnchor, multiplier: 0.7),
            receiverLabel.leadingAnchor.constraint(equalTo: receiverBubblePreview.leadingAnchor, constant: 12),
            receiverLabel.trailingAnchor.constraint(equalTo: receiverBubblePreview.trailingAnchor, constant: -12),
            receiverLabel.topAnchor.constraint(equalTo: receiverBubblePreview.topAnchor, constant: 8),
            receiverLabel.bottomAnchor.constraint(equalTo: receiverBubblePreview.bottomAnchor, constant: -8)
        ])
        
        previewStack.addArrangedSubview(senderContainer)
        previewStack.addArrangedSubview(receiverContainer)
        
        containerStack.addArrangedSubview(labelStack)
        containerStack.addArrangedSubview(cornerRadiusSlider)
        containerStack.addArrangedSubview(previewStack)
        
        cell.contentView.addSubview(containerStack)
        
        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            containerStack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
        
        updateBubblePreviewCorners()
        
        return cell
    }()
    
    private let cornerRadiusSlider = UISlider()
    private let cornerRadiusValueLabel = UILabel()
    private let senderBubblePreview = UIView()
    private let receiverBubblePreview = UIView()
    
    private lazy var resetDefaultsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.resetDefaults.rawValue
        cell.textLabel?.text = String.localized("pref_reset_default_colors")
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = .systemRed
        return cell
    }()
    
    private lazy var sections: [SectionConfigs] = {
        let colorsSection = SectionConfigs(
            headerTitle: String.localized("pref_chat_bubble_colors"),
            footerTitle: String.localized("pref_chat_bubble_colors_explain"),
            cells: [senderBubbleCell, receiverBubbleCell]
        )
        let cornerRadiusSection = SectionConfigs(
            headerTitle: String.localized("pref_bubble_corner_radius"),
            footerTitle: String.localized("pref_bubble_corner_radius_explain"),
            cells: [cornerRadiusCell]
        )
        let resetSection = SectionConfigs(
            cells: [resetDefaultsCell]
        )
        return [colorsSection, cornerRadiusSection, resetSection]
    }()
    
    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_chat_bubbles")
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    // MARK: - UITableViewDelegate + UITableViewDatasource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            return assertionFailure()
        }
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch cellTag {
        case .senderBubble:
            showColorPicker(for: .sender)
        case .receiverBubble:
            showColorPicker(for: .receiver)
        case .cornerRadius:
            break // Slider interaction is handled directly
        case .resetDefaults:
            resetToDefaultColors()
        }
    }
    
    // MARK: - Color Management
    
    private enum BubbleType {
        case sender
        case receiver
    }
    
    private func showColorPicker(for bubbleType: BubbleType) {
        if #available(iOS 14.0, *) {
            let colorPicker = UIColorPickerViewController()
            colorPicker.delegate = self
            
            switch bubbleType {
            case .sender:
                colorPicker.selectedColor = getSenderBubbleColor()
                colorPicker.title = String.localized("pref_sender_bubble_color")
            case .receiver:
                colorPicker.selectedColor = getReceiverBubbleColor()
                colorPicker.title = String.localized("pref_receiver_bubble_color")
            }
            
            // Store the bubble type in the color picker for later reference
            colorPicker.view.tag = bubbleType == .sender ? 1 : 2
            
            present(colorPicker, animated: true)
        } else {
            // Fallback for iOS 13 and earlier - show an alert
            let alert = UIAlertController(
                title: String.localized("pref_chat_bubbles"),
                message: "Color picker requires iOS 14 or later",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
            present(alert, animated: true)
        }
    }
    
    private func getSenderBubbleColor() -> UIColor {
        if let colorData = UserDefaults.standard.data(forKey: Constants.Keys.customSenderBubbleColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            return color
        }
        return DcColors.messagePrimaryColor
    }
    
    private func getReceiverBubbleColor() -> UIColor {
        if let colorData = UserDefaults.standard.data(forKey: Constants.Keys.customReceiverBubbleColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            return color
        }
        return DcColors.messageSecondaryColor
    }
    
    private func saveSenderBubbleColor(_ color: UIColor) {
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: Constants.Keys.customSenderBubbleColorKey)
        }
    }
    
    private func saveReceiverBubbleColor(_ color: UIColor) {
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: Constants.Keys.customReceiverBubbleColorKey)
        }
    }
    
    private func getCurrentCornerRadius() -> Float {
        return Float(BackgroundContainer.getCurrentCornerRadius())
    }
    
    @objc private func cornerRadiusChanged(_ slider: UISlider) {
        let value = slider.value
        cornerRadiusValueLabel.text = String(format: "%.0f", value)
        UserDefaults.standard.set(value, forKey: Constants.Keys.customBubbleCornerRadiusKey)
        updateBubblePreviewCorners()
    }
    
    private func updateBubblePreviewCorners() {
        let radius = BackgroundContainer.getCurrentCornerRadius()
        senderBubblePreview.layer.cornerRadius = radius
        senderBubblePreview.clipsToBounds = true
        receiverBubblePreview.layer.cornerRadius = radius
        receiverBubblePreview.clipsToBounds = true
    }
    
    private func resetToDefaultColors() {
        let alert = UIAlertController(
            title: String.localized("pref_reset_default_colors"),
            message: String.localized("pref_reset_default_colors_confirm"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .destructive) { [weak self] _ in
            UserDefaults.standard.removeObject(forKey: Constants.Keys.customSenderBubbleColorKey)
            UserDefaults.standard.removeObject(forKey: Constants.Keys.customReceiverBubbleColorKey)
            UserDefaults.standard.removeObject(forKey: Constants.Keys.customBubbleCornerRadiusKey)
            self?.updateColorPreviews()
            self?.updateCornerRadiusUI()
        })
        
        present(alert, animated: true)
    }
    
    private func updateCornerRadiusUI() {
        let radius = getCurrentCornerRadius()
        cornerRadiusSlider.value = radius
        cornerRadiusValueLabel.text = String(format: "%.0f", radius)
        updateBubblePreviewCorners()
    }
    
    private func updateColorPreviews() {
        if let senderPreview = senderBubbleCell.accessoryView {
            senderPreview.backgroundColor = getSenderBubbleColor()
        }
        if let receiverPreview = receiverBubbleCell.accessoryView {
            receiverPreview.backgroundColor = getReceiverBubbleColor()
        }
        senderBubblePreview.backgroundColor = getSenderBubbleColor()
        receiverBubblePreview.backgroundColor = getReceiverBubbleColor()
    }
}

// MARK: - UIColorPickerViewControllerDelegate

@available(iOS 14.0, *)
extension ChatBubblesViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        let isSender = viewController.view.tag == 1
        
        if isSender {
            saveSenderBubbleColor(viewController.selectedColor)
        } else {
            saveReceiverBubbleColor(viewController.selectedColor)
        }
        
        updateColorPreviews()
    }
    
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        viewController.dismiss(animated: true)
    }
}
