import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ScreenCaptureKit

struct AmberSettings: Equatable {
    /// -0.5 ... 0.5, added to every pixel's luminance.
    var brightness: Double
    /// 0 ... 2, where 1 leaves contrast unchanged.
    var contrast: Double
    /// 0 (amber) ... 1 (dark orange).
    var tone: Double

    var color: NSColor { AmberFilter.color(tone: tone) }
}

enum AmberFilter {
    static let amber = NSColor(srgbRed: 1, green: 0.69, blue: 0, alpha: 1)
    static let darkOrange = NSColor(srgbRed: 0.55, green: 0.18, blue: 0, alpha: 1)

    private static let black = CIColor(red: 0, green: 0, blue: 0)

    static func color(tone: Double) -> NSColor {
        amber.blended(withFraction: min(max(tone, 0), 1), of: darkOrange) ?? amber
    }

    /// Greyscale with brightness/contrast applied, then mapped from black (shadows) to the tone color (highlights).
    static func apply(_ image: CIImage, _ settings: AmberSettings) -> CIImage {
        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.saturation = 0
        controls.brightness = Float(settings.brightness)
        controls.contrast = Float(settings.contrast)

        let tone = CIFilter.falseColor()
        tone.inputImage = controls.outputImage
        tone.color0 = black
        tone.color1 = CIColor(color: settings.color) ?? CIColor(red: 1, green: 0.69, blue: 0)
        return tone.outputImage ?? image
    }
}

/// Streams the screen region under one pane (excluding this app's own windows) and
/// draws the amber-filtered result into a layer.
final class AmberRenderer: NSObject, SCStreamOutput, SCStreamDelegate {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    private let layer: CALayer
    private let queue = DispatchQueue(label: "AmberGlass.renderer", qos: .userInteractive)
    private var stream: SCStream?

    // Only touched on `queue`.
    private var settings: AmberSettings
    private var lastFrame: CIImage?

    init(layer: CALayer, settings: AmberSettings) {
        self.layer = layer
        self.settings = settings
    }

    /// `sourceRect` is in the display's points with a top-left origin.
    func start(filter: SCContentFilter, sourceRect: CGRect, scale: CGFloat) async throws {
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int((sourceRect.width * scale).rounded())
        config.height = Int((sourceRect.height * scale).rounded())
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.queueDepth = 5

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        stream?.stopCapture { _ in }
        stream = nil
    }

    func update(_ newSettings: AmberSettings) {
        queue.async { [self] in
            settings = newSettings
            if let lastFrame { render(lastFrame) }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer
        else { return }

        let frame = CIImage(cvPixelBuffer: pixelBuffer)
        lastFrame = frame
        render(frame)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("Amber Glass capture stopped: \(error.localizedDescription)")
    }

    private func render(_ frame: CIImage) {
        let output = AmberFilter.apply(frame, settings)
        guard let image = Self.context.createCGImage(output, from: frame.extent) else { return }
        DispatchQueue.main.async { [layer] in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.contents = image
            CATransaction.commit()
        }
    }
}
