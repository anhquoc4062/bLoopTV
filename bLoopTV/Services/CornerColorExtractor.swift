//
//  CornerColorExtractor.swift
//  bLoopTV
//
//  Trích 4 màu góc từ 1 ảnh (poster) để dựng gradient nền — bù cho việc Stremio không có UltraBlurColors
//  như Plex. Toàn bộ tính toán chạy trên background thread, có cache theo key ảnh.
//

import UIKit

enum CornerColorExtractor {
    /// Tỉ lệ vùng góc lấy mẫu (mỗi chiều) — 22% để có vùng đủ lớn lấy màu đại diện, không dính mép 1px.
    private static let cornerFraction = 0.22
    /// Thu nhỏ ảnh về mức này (cạnh dài nhất) trước khi loop pixel cho nhanh; vẫn đủ để tính màu trung bình.
    private static let sampleMaxDimension = 120

    private final class Box { let colors: [UIColor]; init(_ c: [UIColor]) { colors = c } }
    private static let cache = NSCache<NSString, Box>()

    static func cachedColors(for key: String) -> [UIColor]? {
        cache.object(forKey: key as NSString)?.colors
    }

    /// [topLeft, topRight, bottomLeft, bottomRight]. Trả rỗng nếu không đọc được ảnh.
    /// Gọi trên background thread (loop pixel). Kết quả cache theo `key`.
    static func extractCornerColors(from image: UIImage, key: String) -> [UIColor] {
        if let cached = cache.object(forKey: key as NSString)?.colors { return cached }
        guard let cg = image.cgImage else { return [] }

        let ow = cg.width, oh = cg.height
        guard ow > 0, oh > 0 else { return [] }

        let scale = min(1.0, Double(sampleMaxDimension) / Double(max(ow, oh)))
        let w = max(1, Int(Double(ow) * scale))
        let h = max(1, Int(Double(oh) * scale))
        let bytesPerRow = w * 4

        var buf = [UInt8](repeating: 0, count: bytesPerRow * h)
        guard let ctx = CGContext(
            data: &buf,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        // Lật trục Y để hàng 0 trong buffer = MÉP TRÊN của ảnh (khớp thứ tự góc top/bottom).
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let cw = max(1, Int(Double(w) * cornerFraction))
        let ch = max(1, Int(Double(h) * cornerFraction))

        func averageColor(xRange: Range<Int>, yRange: Range<Int>) -> UIColor {
            var r = 0, g = 0, b = 0, n = 0
            var rAll = 0, gAll = 0, bAll = 0, nAll = 0
            for y in yRange {
                let rowOffset = y * bytesPerRow
                for x in xRange {
                    let o = rowOffset + x * 4
                    let pr = Int(buf[o]), pg = Int(buf[o + 1]), pb = Int(buf[o + 2])
                    rAll += pr; gAll += pg; bAll += pb; nAll += 1
                    // Loại outlier: gần trắng thuần (text/logo/border) và gần đen thuần (nền tối).
                    if pr > 240 && pg > 240 && pb > 240 { continue }
                    if pr < 15 && pg < 15 && pb < 15 { continue }
                    r += pr; g += pg; b += pb; n += 1
                }
            }
            // Cả vùng đều là outlier (vd poster nền trắng/đen tuyền) thì đành lấy trung bình tất cả.
            let (sr, sg, sb, count) = n > 0 ? (r, g, b, n) : (rAll, gAll, bAll, max(nAll, 1))
            let base = UIColor(
                red: CGFloat(sr) / CGFloat(count) / 255.0,
                green: CGFloat(sg) / CGFloat(count) / 255.0,
                blue: CGFloat(sb) / CGFloat(count) / 255.0,
                alpha: 1
            )
            return boosted(base)
        }

        let topLeft = averageColor(xRange: 0..<cw, yRange: 0..<ch)
        let topRight = averageColor(xRange: (w - cw)..<w, yRange: 0..<ch)
        let bottomLeft = averageColor(xRange: 0..<cw, yRange: (h - ch)..<h)
        let bottomRight = averageColor(xRange: (w - cw)..<w, yRange: (h - ch)..<h)

        let colors = [topLeft, topRight, bottomLeft, bottomRight]
        cache.setObject(Box(colors), forKey: key as NSString)
        return colors
    }

    /// Màu raw thường nhạt/xám — tăng saturation và kẹp brightness cho gradient có sức sống nhưng không chói.
    private static func boosted(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else { return color }
        sat = min(1.0, sat * 1.4)
        bri = min(0.75, max(0.35, bri))
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1)
    }
}
