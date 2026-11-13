import CoreGraphics

/// Finds the visible part of an image, to drop the transparent margin app icons are drawn with.
public enum ImageTrim {
    /// The smallest rect holding every pixel with alpha of at least `minAlpha`, in image coordinates
    /// (top-left origin, pixels, as `CGImage.cropping(to:)` takes); nil when nothing is that opaque.
    public static func opaqueBounds(of image: CGImage, minAlpha: UInt8 = 128) -> CGRect? {
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }
        // A bitmap context's first row in memory is the image's top row.
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] >= minAlpha {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
