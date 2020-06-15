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
            let height = calculateHeight(width: optimisedWidth)
            self.itemSize = CGSize(width: optimisedWidth, height: height) // keep as square
        case .list:
            self.scrollDirection = .vertical
            let height = calculateHeight(width: containerWidth)
            self.itemSize = CGSize(width: containerWidth, height: height)
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
