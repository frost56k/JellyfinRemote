import Cocoa
import CoreImage.CIFilterBuiltins

public final class QRCodeWindowController: NSWindowController {
    public static let shared = QRCodeWindowController()
    
    private var qrImageView = NSImageView()
    private var urlLabel = NSTextField(labelWithString: "")
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "iPhone Connection"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let headerLabel = NSTextField(labelWithString: "Scan with iPhone Camera")
        headerLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        headerLabel.alignment = .center
        headerLabel.frame = NSRect(x: 10, y: 300, width: 260, height: 24)
        contentView.addSubview(headerLabel)
        
        qrImageView.frame = NSRect(x: 30, y: 70, width: 220, height: 220)
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(qrImageView)
        
        urlLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        urlLabel.alignment = .center
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.frame = NSRect(x: 10, y: 20, width: 260, height: 35)
        contentView.addSubview(urlLabel)
    }
    
    public func show(url: String) {
        urlLabel.stringValue = url
        if let qr = generateQRCode(from: url) {
            qrImageView.image = qr
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
