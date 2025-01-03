import UIKit
import DcCore
class MediaQualityViewController: UITableViewController {

    private var dcContext: DcContext

    private var options: [Int]

    private lazy var staticCells: [UITableViewCell] = {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = MediaQualityViewController.getValString(val: $0)
            return cell
        })
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.options = [Int(DC_MEDIA_QUALITY_BALANCED), Int(DC_MEDIA_QUALITY_WORSE)]
        super.init(style: .insetGrouped)
        self.title = String.localized("pref_outgoing_media_quality")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func getValString(val: Int) -> String {
        switch Int32(val) {
        case DC_MEDIA_QUALITY_BALANCED:
            return String.localized("pref_outgoing_balanced")
        case DC_MEDIA_QUALITY_WORSE:
            return String.localized("pref_outgoing_worse")
        default:
            return "Err"
        }
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up

        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: dcContext.getConfigInt("media_quality"), section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        dcContext.setConfigInt("media_quality", indexPath.row)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if options[indexPath.row] == dcContext.getConfigInt("media_quality") {
            cell.accessoryType = .checkmark
        }
        return cell
    }
}
