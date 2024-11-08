import UIKit

class SwitchCell: UITableViewCell {

    var uiSwitch: UISwitch
    var action: ((SwitchCell) -> Void)?
    static let reuseIdentifier = "SwitchCell"

    var isOn: Bool {
        return uiSwitch.isOn
    }

    init(textLabel: String, on: Bool, action: ((SwitchCell) -> Void)? = nil) {
        self.uiSwitch = UISwitch()
        self.action = action
        super.init(style: .value1, reuseIdentifier: nil)

        self.uiSwitch.setOn(on, animated: false)
        self.uiSwitch.addTarget(self, action: #selector(SwitchCell.didToggleSwitch(_:)), for: .valueChanged)
        self.textLabel?.text = textLabel
        self.accessoryView = uiSwitch
        self.selectionStyle = .none
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func didToggleSwitch(_ sender: UISwitch) {
        action?(self)
    }
}
