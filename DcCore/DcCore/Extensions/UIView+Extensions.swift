import UIKit

public extension UIView {

    func makeBorder(color: UIColor = UIColor.systemRed) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 2
    }

    func alignLeadingToAnchor(_ anchor: NSLayoutXAxisAnchor, paddingLeading: CGFloat = 0.0, priority: UILayoutPriority? = .none) {
        _ = constraintAlignLeadingToAnchor(anchor, paddingLeading: paddingLeading, priority: priority)
    }

    func alignTrailingToAnchor(_ anchor: NSLayoutXAxisAnchor, paddingTrailing: CGFloat = 0.0, priority: UILayoutPriority? = .none) {
        _ = constraintAlignTrailingToAnchor(anchor, paddingTrailing: paddingTrailing, priority: priority)
    }

    func alignTopToAnchor(_ anchor: NSLayoutYAxisAnchor, paddingTop: CGFloat = 0.0, priority: UILayoutPriority? = .none) {
        _ = constraintAlignTopToAnchor(anchor, paddingTop: paddingTop, priority: priority)
    }

    func alignBottomToAnchor(_ anchor: NSLayoutYAxisAnchor, paddingBottom: CGFloat = 0.0, priority: UILayoutPriority? = .none) {
        _ = constraintAlignBottomToAnchor(anchor, paddingBottom: paddingBottom, priority: priority)
    }

    func fill(view: UIView, paddingLeading: CGFloat? = 0.0, paddingTrailing: CGFloat? = 0.0, paddingTop: CGFloat? = 0.0, paddingBottom: CGFloat? = 0.0) {
        alignLeadingToAnchor(view.leadingAnchor, paddingLeading: paddingLeading ??  0.0)
        alignTrailingToAnchor(view.trailingAnchor, paddingTrailing: paddingTrailing ?? 0.0)
        alignTopToAnchor(view.topAnchor, paddingTop: paddingTop ?? 0.0)
        alignBottomToAnchor(view.bottomAnchor, paddingBottom: paddingBottom ?? 0.0)
    }

    func constraintAlignLeadingToAnchor(_ anchor: NSLayoutXAxisAnchor, paddingLeading: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = self.leadingAnchor.constraint(equalTo: anchor, constant: paddingLeading)
        if let priority = priority {
            constraint.priority = priority
        }
        constraint.isActive = true
        return constraint
    }

    func constraintAlignTrailingToAnchor(_ anchor: NSLayoutXAxisAnchor, paddingTrailing: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = self.trailingAnchor.constraint(equalTo: anchor, constant: -paddingTrailing)
        if let priority = priority {
            constraint.priority = priority
        }
        constraint.isActive = true
        return constraint
    }

    func constraintAlignTopToAnchor(_ anchor: NSLayoutYAxisAnchor, paddingTop: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = self.topAnchor.constraint(equalTo: anchor, constant: paddingTop)
        if let priority = priority {
            constraint.priority = priority
        }
        constraint.isActive = true
        return constraint
    }

    func constraintAlignBottomToAnchor(_ anchor: NSLayoutYAxisAnchor, paddingBottom: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = self.bottomAnchor.constraint(equalTo: anchor, constant: -paddingBottom)
        if let priority = priority {
            constraint.priority = priority
        }
        constraint.isActive = true
        return constraint
    }

    func constraintAlignTopTo(_ view: UIView) -> NSLayoutConstraint {
        return constraintAlignTopTo(view, paddingTop: 0.0)
    }

    func constraintAlignTopTo(_ view: UIView, paddingTop: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .top,
            relatedBy: .equal,
            toItem: view,
            attribute: .top,
            multiplier: 1.0,
            constant: paddingTop)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }
    
    /**
     ensure the top of self is aligned with or lower than another view
     can be used in conjunction with constraintAlignCenterY
     */
    func constraintAlignTopMaxTo(_ view: UIView, paddingTop: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .top,
            relatedBy: .greaterThanOrEqual,
            toItem: view,
            attribute: .top,
            multiplier: 1.0,
            constant: paddingTop)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintAlignBottomTo(_ view: UIView, paddingBottom: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .bottom,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 1.0,
            constant: -paddingBottom)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintAlignBottomMaxTo(_ view: UIView, paddingBottom: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .bottom,
            relatedBy: .lessThanOrEqual,
            toItem: view,
            attribute: .bottom,
            multiplier: 1.0,
            constant: -paddingBottom)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintAlignLeadingTo(_ view: UIView, paddingLeading: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .leading,
            relatedBy: .equal,
            toItem: view,
            attribute: .leading,
            multiplier: 1.0,
            constant: paddingLeading)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    /**
        allows to align leading to the leading of another view but allows left side shrinking
     */
    func constraintAlignLeadingMaxTo(_ view: UIView, paddingLeading: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .leading,
            relatedBy: .greaterThanOrEqual,
            toItem: view,
            attribute: .leading,
            multiplier: 1.0,
            constant: paddingLeading)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintAlignTrailingTo(_ view: UIView, paddingTrailing: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .trailing,
            relatedBy: .equal,
            toItem: view,
            attribute: .trailing,
            multiplier: 1.0,
            constant: -paddingTrailing)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    /**
        allows to align trailing to the trailing of another view but allows right side shrinking
     */
    func constraintAlignTrailingMaxTo(_ view: UIView, paddingTrailing: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .trailing,
            relatedBy: .lessThanOrEqual,
            toItem: view,
            attribute: .trailing,
            multiplier: 1.0,
            constant: -paddingTrailing)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintToBottomOf(_ view: UIView, paddingTop: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .top,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 1.0,
            constant: paddingTop)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintToTrailingOf(_ view: UIView, paddingLeading: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .leading,
            relatedBy: .equal,
            toItem: view,
            attribute: .trailing,
            multiplier: 1.0,
            constant: paddingLeading)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintTrailingToLeadingOf(_ view: UIView, paddingTrailing: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: .trailing,
            relatedBy: .equal,
            toItem: view,
            attribute: .leading,
            multiplier: 1.0,
            constant: -paddingTrailing)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintCenterXTo(_ view: UIView, paddingX: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: self,
                                  attribute: .centerX,
                                  relatedBy: .equal,
                                  toItem: view,
                                  attribute: .centerX,
                                  multiplier: 1.0,
                                  constant: paddingX)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintCenterYTo(_ view: UIView, paddingY: CGFloat = 0.0, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: self,
                                  attribute: .centerY,
                                  relatedBy: .equal,
                                  toItem: view,
                                  attribute: .centerY,
                                  multiplier: 1.0,
                                  constant: paddingY)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintHeightTo(_ height: CGFloat, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = heightAnchor.constraint(equalToConstant: height)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func constraintWidthTo(_ width: CGFloat, priority: UILayoutPriority? = .none) -> NSLayoutConstraint {
        let constraint = widthAnchor.constraint(equalToConstant: width)
        if let priority = priority {
            constraint.priority = priority
        }
        return constraint
    }

    func fillSuperview() {
        guard let superview = self.superview else {
            return
        }
        translatesAutoresizingMaskIntoConstraints = false

        let constraints: [NSLayoutConstraint] = [
            leftAnchor.constraint(equalTo: superview.leftAnchor),
            rightAnchor.constraint(equalTo: superview.rightAnchor),
            topAnchor.constraint(equalTo: superview.topAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor)]
        NSLayoutConstraint.activate(constraints)
    }

    func centerInSuperview() {
        guard let superview = self.superview else {
            return
        }
        translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = [
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    func constraint(equalTo size: CGSize) {
        guard superview != nil else { return }
        translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = [
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height)
        ]
        NSLayoutConstraint.activate(constraints)

    }

    @discardableResult
    func addConstraints(_ top: NSLayoutYAxisAnchor? = nil, left: NSLayoutXAxisAnchor? = nil, bottom: NSLayoutYAxisAnchor? = nil, right: NSLayoutXAxisAnchor? = nil, centerY: NSLayoutYAxisAnchor? = nil, centerX: NSLayoutXAxisAnchor? = nil, topConstant: CGFloat = 0, leftConstant: CGFloat = 0, bottomConstant: CGFloat = 0, rightConstant: CGFloat = 0, centerYConstant: CGFloat = 0, centerXConstant: CGFloat = 0, widthConstant: CGFloat = 0, heightConstant: CGFloat = 0) -> [NSLayoutConstraint] {

        if self.superview == nil {
            return []
        }
        translatesAutoresizingMaskIntoConstraints = false

        var constraints = [NSLayoutConstraint]()

        if let top = top {
            let constraint = topAnchor.constraint(equalTo: top, constant: topConstant)
            constraint.identifier = "top"
            constraints.append(constraint)
        }
        if let left = left {
            let constraint = leftAnchor.constraint(equalTo: left, constant: leftConstant)
            constraint.identifier = "left"
            constraints.append(constraint)
        }

        if let bottom = bottom {
            let constraint = bottomAnchor.constraint(equalTo: bottom, constant: -bottomConstant)
            constraint.identifier = "bottom"
            constraints.append(constraint)
        }

        if let right = right {
            let constraint = rightAnchor.constraint(equalTo: right, constant: -rightConstant)
            constraint.identifier = "right"
            constraints.append(constraint)
        }

        if let centerY = centerY {
            let constraint = centerYAnchor.constraint(equalTo: centerY, constant: centerYConstant)
            constraint.identifier = "centerY"
            constraints.append(constraint)
        }

        if let centerX = centerX {
            let constraint = centerXAnchor.constraint(equalTo: centerX, constant: centerXConstant)
            constraint.identifier = "centerX"
            constraints.append(constraint)
        }

        if widthConstant > 0 {
            let constraint = widthAnchor.constraint(equalToConstant: widthConstant)
            constraint.identifier = "width"
            constraints.append(constraint)
        }

        if heightConstant > 0 {
            let constraint = heightAnchor.constraint(equalToConstant: heightConstant)
            constraint.identifier = "height"
            constraints.append(constraint)
        }

        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
