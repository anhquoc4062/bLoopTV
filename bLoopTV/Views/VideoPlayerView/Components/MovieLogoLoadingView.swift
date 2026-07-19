//
//  MovieLogoLoadingView.swift
//  bLoopTV
//
//  Lúc video đang tải trong player, hiện LOGO CỦA PHIM (clearLogo) nhịp thở — giống kiểu loading của
//  Stremio. Không có logo thì lùi về spinner cam.
//

import SwiftUI
import SDWebImageSwiftUI

struct MovieLogoLoadingView: View {
    let logoUrlString: String?

    @State private var animating = false

    private var logoURL: URL? {
        guard let s = logoUrlString, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var body: some View {
        Group {
            if let logoURL {
                WebImage(url: logoURL, options: [.scaleDownLargeImages]) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    // KHÔNG spinner ở đây — có logo thì chỉ hiện logo (đang tải thì để trống, khỏi lòi spinner).
                    Color.clear
                }
                .frame(maxWidth: 440, maxHeight: 220)
                // Logo clearLogo thường là chữ TRẮNG nền trong suốt — thêm shadow đen cho nổi trên thumbnail.
                .shadow(color: .black.opacity(0.7), radius: 14, x: 0, y: 2)
                .scaleEffect(animating ? 1.0 : 0.8)
                .opacity(animating ? 1.0 : 0.4)
                // Dùng withAnimation trong onAppear (không dùng .animation(value:) vì kiểu đó + repeatForever
                // hay lỗi khiến opacity rơi về ~0 = mất logo, thay vì dừng ở sàn 0.4 như bên iOS).
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        animating = true
                    }
                }
            } else {
                OrangeSpinner().frame(width: 60, height: 60)
            }
        }
    }
}
