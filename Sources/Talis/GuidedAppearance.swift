import AppKit
import QuartzCore

/// Brand color and quiet radial light sit behind controls, never text content.
final class GuidedAccentView: NSView {
    private let gradient = CAGradientLayer()
    private let halos = (0..<3).map { _ in CALayer() }
    private let motionPreference: () -> Bool
    private var motionObserver: NSObjectProtocol?

    init(frame: NSRect, motionPreference: @escaping () -> Bool = { AppTheme.reducesMotion }) {
        self.motionPreference = motionPreference
        super.init(frame: frame)
        wantsLayer = true
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 0, y: 0)
        layer?.addSublayer(gradient)
        for halo in halos {
            halo.contentsGravity = .resize
            layer?.addSublayer(halo)
        }
        motionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.updateMotion() }
    }

    required init?(coder: NSCoder) {
        motionPreference = { AppTheme.reducesMotion }
        super.init(coder: coder)
    }
    deinit { if let motionObserver { NSWorkspace.shared.notificationCenter.removeObserver(motionObserver) } }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var wantsUpdateLayer: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMotion()
    }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradient.frame = bounds
        let frames = [
            CGRect(x: -bounds.width * 0.16, y: -bounds.height * 0.52, width: bounds.width * 0.76, height: bounds.height * 1.65),
            CGRect(x: bounds.width * 0.62, y: -bounds.height * 0.42, width: bounds.width * 0.62, height: bounds.height * 1.45),
            CGRect(x: bounds.width * 0.32, y: bounds.height * 0.04, width: bounds.width * 0.44, height: bounds.height * 0.92)
        ]
        for (halo, frame) in zip(halos, frames) {
            halo.frame = frame
        }
        CATransaction.commit()
    }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            gradient.colors = [
                AppTheme.accentColor.withAlphaComponent(0.12).cgColor,
                AppTheme.accentColor.withAlphaComponent(0.035).cgColor,
                NSColor.clear.cgColor
            ]
            let image = makeHaloImage()
            for halo in halos { halo.contents = image }
        }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    private func makeHaloImage() -> CGImage? {
        let size = 256
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let haloGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                AppTheme.accentColor.withAlphaComponent(0.16).cgColor,
                AppTheme.accentColor.withAlphaComponent(0.045).cgColor,
                NSColor.clear.cgColor
            ] as CFArray,
            locations: [0, 0.48, 1]
        ) else { return nil }
        let center = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(
            haloGradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(size / 2),
            options: [.drawsAfterEndLocation]
        )
        return context.makeImage()
    }

    private func updateMotion() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (index, halo) in halos.enumerated() {
            halo.removeAllAnimations()
            halo.transform = CATransform3DIdentity
            guard window != nil, !motionPreference() else { continue }
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let horizontal = CABasicAnimation(keyPath: "transform.translation.x")
            horizontal.fromValue = -10 * direction
            horizontal.toValue = 14 * direction
            horizontal.duration = 20 + Double(index) * 4
            horizontal.autoreverses = true
            horizontal.repeatCount = .infinity
            horizontal.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            halo.add(horizontal, forKey: "halo.horizontal")
            let vertical = CABasicAnimation(keyPath: "transform.translation.y")
            vertical.fromValue = -5 * direction
            vertical.toValue = 7 * direction
            vertical.duration = 24 + Double(index) * 3
            vertical.autoreverses = true
            vertical.repeatCount = .infinity
            vertical.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            halo.add(vertical, forKey: "halo.vertical")
        }
        CATransaction.commit()
    }
}

final class GuidedIdentityView: NSView {
    private let gradient = CAGradientLayer()
    private let symbol = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.cornerRadius = 11
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        layer?.addSublayer(gradient)
        layer?.cornerRadius = 11
        layer?.shadowOpacity = 0.13
        layer?.shadowRadius = 5
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        symbol.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            symbol.image = icon
            gradient.isHidden = true
            layer?.shadowOpacity = 0
        }
        symbol.wantsLayer = true
        symbol.setAccessibilityElement(false)
        symbol.contentTintColor = nil
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbol)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 36), heightAnchor.constraint(equalToConstant: 36),
            symbol.centerXAnchor.constraint(equalTo: centerXAnchor), symbol.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbol.widthAnchor.constraint(equalToConstant: 36),
            symbol.heightAnchor.constraint(equalToConstant: 36)
        ])
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var wantsUpdateLayer: Bool { true }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            gradient.colors = [AppTheme.accentColor.blended(withFraction: 0.2, of: .white)!.cgColor,
                               AppTheme.accentColor.cgColor]
        }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}
