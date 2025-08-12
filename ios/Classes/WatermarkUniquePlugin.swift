import Flutter
import UIKit
import CoreMotion

public class WatermarkUniquePlugin: NSObject, FlutterPlugin {
    // 用于检测设备方向
    private let motionManager = CMMotionManager()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "WatermarkImage", binaryMessenger: registrar.messenger())
        let instance = WatermarkUniquePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing arguments", details: nil))
            return
        }

        switch call.method {
        case "addTextWatermark":
            handleAddTextWatermark(arguments: arguments, result: result)
        case "addImageWatermark":
            handleAddImageWatermark(arguments: arguments, result: result)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleAddTextWatermark(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let filePath = arguments["filePath"] as? String,
              let text = arguments["text"] as? String,
              let textSize = arguments["textSize"] as? CGFloat,
              let colorHex = arguments["color"] as? Int,
              let color = UIColor(rgb: colorHex),
              let quality = arguments["quality"] as? CGFloat,
              let imageFormat = arguments["imageFormat"] as? String else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing or invalid arguments", details: nil))
            return
        }

        // 获取旋转角度，默认为 0
        let rotateAngle = arguments["rotateAngle"] as? CGFloat ?? 0

        let backgroundTextColor: UIColor? = {
            if let colorBackgroundHex = arguments["backgroundTextColor"] as? Int {
                return UIColor(rgb: colorBackgroundHex)
            }
            return nil
        }()

        addTextWatermark(
            text: text,
            filePath: filePath,
            textWatermarkSize: textSize,
            colorWatermark: color,
            backgroundTextColor: backgroundTextColor,
            quality: quality,
            backgroundTextPaddingTop: arguments["backgroundTextPaddingTop"] as? CGFloat,
            backgroundTextPaddingBottom: arguments["backgroundTextPaddingBottom"] as? CGFloat,
            backgroundTextPaddingLeft: arguments["backgroundTextPaddingLeft"] as? CGFloat,
            backgroundTextPaddingRight: arguments["backgroundTextPaddingRight"] as? CGFloat,
            imageFormat: imageFormat,
            rotateAngle: rotateAngle
        ) { newFilePath, error in
            if let error = error {
                result(FlutterError(code: "PROCESSING_ERROR", message: error.localizedDescription, details: nil))
            } else if let newFilePath = newFilePath {
                result(newFilePath)
            } else {
                result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown error occurred", details: nil))
            }
        }
    }

    private func handleAddImageWatermark(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let filePath = arguments["filePath"] as? String,
              let watermarkImagePath = arguments["watermarkImagePath"] as? String,
              let watermarkWidth = arguments["watermarkWidth"] as? CGFloat,
              let watermarkHeight = arguments["watermarkHeight"] as? CGFloat,
              let quality = arguments["quality"] as? CGFloat,
              let imageFormat = arguments["imageFormat"] as? String else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing or invalid arguments", details: nil))
            return
        }

        // 获取旋转角度，默认为 0
        let rotateAngle = arguments["rotateAngle"] as? CGFloat ?? 0

        addImageWatermark(
            filePath: filePath,
            watermarkImagePath: watermarkImagePath,
            watermarkWidth: watermarkWidth,
            watermarkHeight: watermarkHeight,
            quality: quality,
            imageFormat: imageFormat,
            rotateAngle: rotateAngle
        ) { newFilePath, error in
            if let error = error {
                result(FlutterError(code: "PROCESSING_ERROR", message: error.localizedDescription, details: nil))
            } else if let newFilePath = newFilePath {
                result(newFilePath)
            } else {
                result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown error occurred", details: nil))
            }
        }
    }

    func addTextWatermark(
        text: String,
        filePath: String,
        textWatermarkSize: CGFloat,
        colorWatermark: UIColor,
        backgroundTextColor: UIColor?,
        quality: CGFloat,
        backgroundTextPaddingTop: CGFloat?,
        backgroundTextPaddingBottom: CGFloat?,
        backgroundTextPaddingLeft: CGFloat?,
        backgroundTextPaddingRight: CGFloat?,
        imageFormat: String,
        rotateAngle: CGFloat,
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard var image = UIImage(contentsOfFile: filePath) else {
            completion(nil, NSError(domain: "ImageProcessorErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
            return
        }

        // 旋转图片到正常角度
        if rotateAngle != 0 {
            image = image.rotated(by: rotateAngle) ?? image
        }

        DispatchQueue.global().async {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let font = UIFont.systemFont(ofSize: textWatermarkSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: colorWatermark
            ]

            // 计算最大宽度（考虑边距）
            let maxWidth = image.size.width - 10 // 左右各5px边距

            // 计算文本行
            let lines = self.wrappedText(text, width: maxWidth, font: font)

            // 计算文本块总高度
            var totalHeight: CGFloat = 0
            for line in lines {
                let size = line.size(withAttributes: attributes)
                totalHeight += size.height
            }

            // 计算起始位置（左下角，距离边缘5px）
            let startX: CGFloat = 5
            let startY: CGFloat = image.size.height - totalHeight - 5

            var currentY = startY

            for line in lines {
                let size = line.size(withAttributes: attributes)
                let textRect = CGRect(x: startX, y: currentY, width: size.width, height: size.height)

                let backgroundRect = textRect.inset(by: UIEdgeInsets(
                    top: -(backgroundTextPaddingTop ?? 0),
                    left: -(backgroundTextPaddingLeft ?? 0),
                    bottom: -(backgroundTextPaddingBottom ?? 0),
                    right: -(backgroundTextPaddingRight ?? 0))
                )

                if let bgColor = backgroundTextColor {
                    bgColor.setFill()
                    UIRectFill(backgroundRect)
                }

                line.draw(in: textRect, withAttributes: attributes)
                currentY += size.height
            }

            guard let newImage = UIGraphicsGetImageFromCurrentImageContext(),
                  let data = self.imageData(from: newImage, format: imageFormat, quality: quality) else {
                UIGraphicsEndImageContext()
                completion(nil, NSError(domain: "ImageProcessorErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create new image"]))
                return
            }

            UIGraphicsEndImageContext()

            let newPath = (filePath as NSString).deletingLastPathComponent + "/\(UUID().uuidString).\(imageFormat)"

            do {
                try data.write(to: URL(fileURLWithPath: newPath), options: .atomic)
                completion(newPath, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    func addImageWatermark(
        filePath: String,
        watermarkImagePath: String,
        watermarkWidth: CGFloat,
        watermarkHeight: CGFloat,
        quality: CGFloat,
        imageFormat: String,
        rotateAngle: CGFloat,
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard var image = UIImage(contentsOfFile: filePath),
              let watermark = UIImage(contentsOfFile: watermarkImagePath) else {
            completion(nil, NSError(domain: "READ_ERROR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load images"]))
            return
        }

        // 旋转图片到正常角度
        if rotateAngle != 0 {
            image = image.rotated(by: rotateAngle) ?? image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))

        // 计算水印位置（左下角，距离边缘5px）
        let x: CGFloat = 5
        let y: CGFloat = image.size.height - watermarkHeight - 5

        watermark.draw(in: CGRect(x: x, y: y, width: watermarkWidth, height: watermarkHeight))

        guard let newImage = UIGraphicsGetImageFromCurrentImageContext(),
              let data = self.imageData(from: newImage, format: imageFormat, quality: quality) else {
            UIGraphicsEndImageContext()
            completion(nil, NSError(domain: "CONVERSION_ERROR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"]))
            return
        }

        UIGraphicsEndImageContext()

        let newPath = (filePath as NSString).deletingLastPathComponent + "/\(UUID().uuidString).\(imageFormat)"

        do {
            try data.write(to: URL(fileURLWithPath: newPath), options: .atomic)
            completion(newPath, nil)
        } catch {
            completion(nil, error)
        }
    }

    private func imageData(from image: UIImage, format: String, quality: CGFloat) -> Data? {
        switch format.lowercased() {
        case "png":
            return image.pngData()
        case "jpeg", "jpg":
            return image.jpegData(compressionQuality: quality / 100)
        default:
            return image.pngData()
        }
    }

    private func wrappedText(_ text: String, width: CGFloat, font: UIFont) -> [String] {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let testSize = testLine.size(withAttributes: [.font: font])

            if testSize.width <= width {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = String(word)
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }
}

extension UIImage {
    /// 根据角度旋转图片
    func rotated(by degrees: CGFloat) -> UIImage? {
        // 将角度转换为弧度
        let radians = degrees * .pi / 180

        // 计算旋转后的尺寸
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size

        // 创建上下文
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // 移动到中心点
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)

        // 旋转
        context.rotate(by: radians)

        // 绘制图片
        draw(in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))

        // 获取旋转后的图片
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
}

extension UIColor {
    convenience init?(rgb: Int) {
        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0
        let alpha = CGFloat((rgb >> 24) & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}