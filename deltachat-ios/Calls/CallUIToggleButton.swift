import UIKit

class CallUIToggleButton: UIButton {
    private let size: CGFloat
    var toggleState: Bool {
        didSet { updateState(toggleState) }
    }

    init(imageSystemName: String, size: CGFloat = 70, state: Bool) {
        self.size = size
        self.toggleState = state
        super.init(frame: .zero)
        self.setImage(UIImage(systemName: imageSystemName), for: .normal)
        self.setPreferredSymbolConfiguration(.init(pointSize: size * 0.4), forImageIn: .normal)
        self.layer.cornerRadius = size / 2
        self.layer.masksToBounds = true
        self.updateState(state)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateState(_ state: Bool) {
        backgroundColor = toggleState ? .white : .darkGray
        tintColor = toggleState ? .darkText : .lightText
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        constraint(equalTo: CGSize(width: size, height: size))
    }
}
