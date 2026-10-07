import Flutter
import ImageIO
import Vision

/// Reads the lines of text on a photo with Vision for Scan to Pay, over the
/// `boctrust/scan_text` channel. Boxes are returned top-left, normalized to
/// the upright image.
enum ScanTextRecognizer {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "boctrust/scan_text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        result(FlutterError(code: "invalid_argument", message: "A path is required.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let lines = try recognizeLines(at: URL(fileURLWithPath: path))
          DispatchQueue.main.async { result(lines) }
        } catch {
          // The error may name the file; send only a fixed message.
          DispatchQueue.main.async {
            result(FlutterError(code: "recognition_failed", message: "Text recognition failed.", details: nil))
          }
        }
      }
    }
  }

  private static func recognizeLines(at url: URL) throws -> [[String: Any]] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // With the file's orientation, Vision reports boxes on the upright image.
    let handler = VNImageRequestHandler(url: url, orientation: orientation(of: url), options: [:])
    try handler.perform([request])
    return (request.results ?? []).compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      // Vision's origin is bottom-left; the shared contract is top-left.
      let box = observation.boundingBox
      return [
        "text": candidate.string,
        "left": Double(box.origin.x),
        "top": Double(1 - (box.origin.y + box.height)),
        "width": Double(box.width),
        "height": Double(box.height),
      ]
    }
  }

  private static func orientation(of url: URL) -> CGImagePropertyOrientation {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }
    return orientation
  }
}
