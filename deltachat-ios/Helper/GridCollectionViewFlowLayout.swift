import UIKit

enum GridItemFormat {
    case square
    case rect(ratio: CGFloat)
}

enum GridDisplay {
    case list
    case grid(columns: Int)
}

extension GridDisplay: Equatable {

    public static func == (lhs: GridDisplay, rhs: GridDisplay) -> Bool {
        switch (lhs, rhs) {
        case (.list, .list):
            return true
        case (.grid(let lColumn), .grid(let rColumn)):
            return lColumn == rColumn

        default:
            return false
        }
    }
}

// MARK: - GridCollectionViewFlowLayout
// FIXME: Replace with `UICollectionViewCompositionalLayout`?
class GridCollectionViewFlowLayout: UICollectionViewFlowLayout {

    var display: GridDisplay = .list {
        didSet {
            if display != oldValue {
                self.invalidateLayout()
            }
        }
    }

    var containerWidth: CGFloat = 0.0 {
        didSet {
            if containerWidth != oldValue {
                self.invalidateLayout()
            }
        }
    }

    var format: GridItemFormat = .square {
        didSet {
            self.invalidateLayout()
        }
    }

    convenience init(display: GridDisplay, containerWidth: CGFloat, format: GridItemFormat) {
        self.init()
        self.display = display
        self.containerWidth = containerWidth
        self.format = format
        self.configLayout()
    }

    private func configLayout() {
        switch display {
        case .grid(let column):
            self.scrollDirection = .vertical
            let spacing = CGFloat(column - 1) * minimumLineSpacing
            let optimisedWidth = (containerWidth - spacing) / CGFloat(column)
            if optimisedWidth > 0 {
                self.itemSize = CGSize(width: optimisedWidth, height: calculateHeight(width: optimisedWidth))
            }
        case .list:
            self.scrollDirection = .vertical
            if containerWidth > 0 {
                self.itemSize = CGSize(width: containerWidth, height: calculateHeight(width: containerWidth))
            }
        }
    }

    private func calculateHeight(width: CGFloat) -> CGFloat {
        switch format {
        case .square:
            return width
        case .rect(let ratio):
            return width * ratio
        }
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        self.configLayout()
    }
}
