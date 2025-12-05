import UIKit
import DcCore

class ChatBubblesViewController: UITableViewController {
    
    private let dcContext: DcContext
    
    private enum CellTags: Int {
        case senderBubble
        case receiverBubble
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
        let resetSection = SectionConfigs(
            cells: [resetDefaultsCell]
        )
        return [colorsSection, resetSection]
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
            self?.updateColorPreviews()
        })
        
        present(alert, animated: true)
    }
    
    private func updateColorPreviews() {
        if let senderPreview = senderBubbleCell.accessoryView {
            senderPreview.backgroundColor = getSenderBubbleColor()
        }
        if let receiverPreview = receiverBubbleCell.accessoryView {
            receiverPreview.backgroundColor = getReceiverBubbleColor()
        }
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
