//
//  DetailHeroBanner.swift
//  bLoopTV
//
//  Ảnh nền hero của trang detail, dùng chung cho Plex và Stremio (trước đây mỗi bên chép một bản y hệt).
//

import SwiftUI

/// Neo ảnh về bên phải, chỉ chiếm 90% chiều rộng + mask mờ dần sang trái và xuống dưới để hoà vào nền —
/// tránh bị crop lộ liễu khi ảnh nguồn không đúng tỉ lệ màn hình. Ảnh tự fade-in khi giải mã xong.
struct DetailHeroBanner: View {
    let imageURL: URL?
    let screenWidth: CGFloat
    var height: CGFloat = 880

    private var bannerWidth: CGFloat { screenWidth * 0.90 }

    var body: some View {
        FadeInWebImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: bannerWidth, height: height)
                .clipped()
                .mask(bannerMask)
        }
        .frame(width: bannerWidth, height: height)
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .trailing)
    }

    private var bannerMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.1),
                .init(color: .white, location: 0.3),
                .init(color: .clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.2), location: 0.15),
                    .init(color: .black, location: 0.40),
                    .init(color: .black, location: 0.80),
                    .init(color: .black, location: 0.99)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .compositingGroup()
    }
}
