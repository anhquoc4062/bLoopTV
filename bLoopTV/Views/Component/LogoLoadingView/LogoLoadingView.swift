//
//  LogoLoadingView.swift
//  bLoopTV
//
//  Màn loading dùng logo app (nhịp thở phóng to/mờ dần) thay cho spinner — giống kiểu loading của Stremio.
//  Dùng chung cho Home của Plex lẫn Stremio.
//

import SwiftUI

struct LogoLoadingView: View {
    var size: CGFloat = 120

    @State private var animating = false

    var body: some View {
        Image("bLoopIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(animating ? 1.0 : 0.82)
            .opacity(animating ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
            .frame(maxWidth: .infinity)
    }
}
