import UIKit

/// A view that displays an animated waveform visualization for audio playback
class WaveformView: UIView {
    
    // MARK: - Properties
    
    /// Number of bars in the waveform
    private let numberOfBars: Int = 30
    
    /// Current playback progress (0.0 to 1.0)
    private var progress: Float = 0.0
    
    /// Color for played portion of waveform
    var playedColor: UIColor = .systemBlue {
        didSet { setNeedsDisplay() }
    }
    
    /// Color for unplayed portion of waveform
    var unplayedColor: UIColor = .systemGray3 {
        didSet { setNeedsDisplay() }
    }
    
    /// Spacing between bars
    private let barSpacing: CGFloat = 2.0
    
    /// Corner radius for bars
    private let barCornerRadius: CGFloat = 1.5
    
    /// Heights for each bar (normalized 0.0 to 1.0)
    private var barHeights: [CGFloat] = []
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isAccessibilityElement = false
        generateWaveformData()
    }
    
    /// Generates random waveform heights for visualization
    /// In a real implementation, these could be based on actual audio amplitude data
    private func generateWaveformData() {
        barHeights = (0..<numberOfBars).map { index in
            // Create a more natural-looking waveform pattern
            let normalized = CGFloat(index) / CGFloat(numberOfBars)
            let sine = sin(normalized * .pi * 2.0) * 0.3
            let random = CGFloat.random(in: 0.3...1.0)
            return max(0.2, min(1.0, random + sine))
        }
    }
    
    // MARK: - Public Methods
    
    /// Updates the playback progress
    /// - Parameter progress: Progress value between 0.0 and 1.0
    func setProgress(_ progress: Float) {
        self.progress = max(0.0, min(1.0, progress))
        setNeedsDisplay()
    }
    
    /// Resets the waveform to initial state
    func reset() {
        progress = 0.0
        generateWaveformData()
        setNeedsDisplay()
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let totalSpacing = barSpacing * CGFloat(numberOfBars - 1)
        let availableWidth = rect.width - totalSpacing
        let barWidth = availableWidth / CGFloat(numberOfBars)
        
        // Calculate progress bar index
        let progressBarIndex = Int(CGFloat(numberOfBars) * CGFloat(progress))
        
        for (index, heightRatio) in barHeights.enumerated() {
            let x = CGFloat(index) * (barWidth + barSpacing)
            
            // Bar height varies based on the waveform data
            let maxBarHeight = rect.height * 0.8
            let minBarHeight = rect.height * 0.2
            let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * heightRatio
            
            // Center the bar vertically
            let y = (rect.height - barHeight) / 2
            
            // Choose color based on whether this bar has been played
            // Use <= so the bar containing the current position is also marked as played
            let color = index <= progressBarIndex ? playedColor : unplayedColor
            context.setFillColor(color.cgColor)
            
            // Draw rounded rectangle for each bar
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barCornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
}
