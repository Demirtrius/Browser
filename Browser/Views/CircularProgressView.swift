import UIKit

class CircularProgressView: UIView {
    
    var progress: Double = 0 {
        didSet { setNeedsDisplay() }
    }
    
    var lineWidth: CGFloat = 3
    var trackColor: UIColor = UIColor(white: 1, alpha: 0.15)
    var progressColor: UIColor = UIColor(hex: 0x6CB4FF)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isHidden = true  // Start hidden, only show when downloads active
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        
        // Track
        ctx.beginPath()
        ctx.addArc(center: center, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi * 1.5, clockwise: false)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(trackColor.cgColor)
        ctx.setLineCap(.round)
        ctx.strokePath()
        
        // Progress arc
        guard progress > 0 else { return }
        let endAngle = -CGFloat.pi / 2 + CGFloat.pi * 2 * CGFloat(min(max(progress, 0), 1))
        ctx.beginPath()
        ctx.addArc(center: center, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: endAngle, clockwise: false)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(progressColor.cgColor)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }
}
