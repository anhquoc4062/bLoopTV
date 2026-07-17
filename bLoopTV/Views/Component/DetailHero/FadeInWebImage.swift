//
//  FadeInWebImage.swift
//  bLoopTV
//
//  Tách khỏi MovieDetailView để trang detail của cả Plex lẫn Stremio dùng chung.
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

/// WebImage tự fade-in mượt đúng lúc ảnh giải mã xong (onSuccess) thay vì pop/nháy. Reset khi url đổi để
/// lần load mới cũng fade lại từ đầu.
struct FadeInWebImage<Content: View>: View {
    let url: URL?
    var options: SDWebImageOptions = [.scaleDownLargeImages]
    @ViewBuilder let content: (Image) -> Content

    @State private var visible = false

    /// Ảnh đã nằm trong cache (memory/disk) — vào lại view thì hiện ngay, không chờ fade.
    private func isCached(_ url: URL?) -> Bool {
        guard let url else { return false }
        let key = SDWebImageManager.shared.cacheKey(for: url)
        return SDImageCache.shared.imageFromCache(forKey: key) != nil
    }

    var body: some View {
        WebImage(url: url, options: options) { image in
            content(image)
        } placeholder: {
            Color.clear
        }
        .onSuccess { _, _, cacheType in
            // Ảnh từ memory cache gọi onSuccess ĐỒNG BỘ ngay trong lúc render — set @State trực tiếp lúc
            // này sẽ bị SwiftUI bỏ qua khiến ảnh kẹt opacity 0. async ra khỏi vòng render mới ăn state.
            DispatchQueue.main.async {
                if visible { return }
                if cacheType == .none {
                    withAnimation(.easeIn(duration: 0.5)) { visible = true }
                } else {
                    visible = true // đã cache → hiện ngay, khỏi fade
                }
            }
        }
        .cancelOnDisappear(true)
        .opacity(visible ? 1 : 0)
        .onAppear {
            // Vào lại detail khi ảnh đã cache: hiện ngay, phòng trường hợp onSuccess không tái phát.
            if isCached(url) { visible = true }
        }
        .onChange(of: url) { newURL in
            visible = isCached(newURL)
        }
    }
}
