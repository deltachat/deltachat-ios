import UIKit

public class DynamicFontButton: UIButton {

    override public var intrinsicContentSize: CGSize {
        if let size = self.titleLabel?.intrinsicContentSize {
            return CGSize(width: size.width + contentEdgeInsets.left + contentEdgeInsets.right,
                          height: size.height + contentEdgeInsets.top + contentEdgeInsets.bottom)
        }

        return super.intrinsicContentSize
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        titleLabel?.preferredMaxLayoutWidth = self.titleLabel!.frame.size.width
    }
}
