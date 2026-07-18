//
//  CornerGradientBackground.swift
//  bLoopTV
//
//  Gradient nền dựng từ 4 màu góc [topLeft, topRight, bottomLeft, bottomRight]. Ưu tiên MeshGradient
//  (tvOS 18+), fallback 4 lớp RadialGradient xếp chồng (giống backgroundLayer bên Plex).
//

import SwiftUI

struct CornerGradientBackground: View {
    /// Đúng thứ tự [topLeft, topRight, bottomLeft, bottomRight].
    let colors: [Color]

    var body: some View {
        if colors.count == 4 {
            if #available(tvOS 18.0, *) {
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0, 0], [1, 0],   // topLeft, topRight
                        [0, 1], [1, 1]    // bottomLeft, bottomRight
                    ],
                    colors: colors
                )
                .overlay(Color.black.opacity(0.25)) // dịu lại để chữ/nút vẫn đọc rõ
            } else {
                radialFallback
            }
        } else {
            Color("BackgroundColor")
        }
    }

    private var radialFallback: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height)
            ZStack {
                Color.black
                RadialGradient(colors: [colors[2], .clear], center: .bottomLeading, startRadius: 0, endRadius: r)
                RadialGradient(colors: [colors[3], .clear], center: .bottomTrailing, startRadius: 0, endRadius: r)
                RadialGradient(colors: [colors[1], .clear], center: .topTrailing, startRadius: 0, endRadius: r)
                RadialGradient(colors: [colors[0], .clear], center: .topLeading, startRadius: 0, endRadius: r)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .drawingGroup()
    }
}
