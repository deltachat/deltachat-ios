import UIKit
import DcCore

class CustomizationViewController: UITableViewController {
    
    private let dcContext: DcContext
    
    private enum CellTags: Int {
        case wallpaper
        case chatBubbles
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
    
    private lazy var wallpaperCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.wallpaper.rawValue
        cell.textLabel?.text = String.localized("pref_background")
        cell.imageView?.image = UIImage(systemName: "photo")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()
    
    private lazy var chatBubblesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.chatBubbles.rawValue
        cell.textLabel?.text = String.localized("pref_chat_bubbles")
        cell.imageView?.image = UIImage(systemName: "bubble.left.and.bubble.right")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()
    
    private lazy var sections: [SectionConfigs] = {
        let customizationSection = SectionConfigs(
            headerTitle: String.localized("pref_customization"),
            footerTitle: String.localized("pref_customization_explain"),
            cells: [wallpaperCell, chatBubblesCell]
        )
        return [customizationSection]
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
        title = String.localized("pref_customization")
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
        case .wallpaper:
            showWallpaperSettings()
        case .chatBubbles:
            showChatBubblesSettings()
        }
    }
    
    // MARK: - Navigation
    
    private func showWallpaperSettings() {
        navigationController?.pushViewController(BackgroundOptionsViewController(dcContext: dcContext), animated: true)
    }
    
    private func showChatBubblesSettings() {
        navigationController?.pushViewController(ChatBubblesViewController(dcContext: dcContext), animated: true)
    }
}
