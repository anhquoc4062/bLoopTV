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
                    OrangeSpinner().frame(width: 60, height: 60)
                }
                .frame(maxWidth: 360, maxHeight: 180)
                .scaleEffect(animating ? 1.0 : 0.9)
                .opacity(animating ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animating)
                .onAppear { animating = true }
            } else {
                OrangeSpinner().frame(width: 60, height: 60)
            }
        }
    }
}
