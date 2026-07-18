//
//  PosterCornerColorsModel.swift
//  bLoopTV
//
//  Nạp ảnh poster (qua cache SDWebImage) rồi trích 4 màu góc để làm gradient nền cho trang detail Stremio.
//

import SwiftUI
import Combine
import SDWebImage

@MainActor
final class PosterCornerColorsModel: ObservableObject {
    /// [topLeft, topRight, bottomLeft, bottomRight]. Rỗng = chưa có → view dùng nền mặc định.
    @Published private(set) var colors: [Color] = []

    private var loadedKey: String?

    func load(urlString: String?) {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return }
        guard loadedKey != urlString else { return } // đã nạp cho ảnh này rồi
        loadedKey = urlString

        // Có sẵn trong cache màu thì set ngay, khỏi tải ảnh.
        if let cached = CornerColorExtractor.cachedColors(for: urlString) {
            colors = cached.map(Color.init)
            return
        }

        SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { [weak self] image, _, _, _, _, _ in
            guard let self, let image else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let ui = CornerColorExtractor.extractCornerColors(from: image, key: urlString)
                guard !ui.isEmpty else { return }
                let swiftColors = ui.map(Color.init)
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.colors = swiftColors
                    }
                }
            }
        }
    }
}
