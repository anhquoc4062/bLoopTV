//
//  StremioMovieCardView.swift
//  bLoopTV
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

/// Đồng bộ style với MovieCardView (Views/Component/MovieCardView) nhưng dùng dữ liệu Stremio (StremioMeta)
/// thay vì PlexMetaData, và poster là URL thô (không qua transcode của Plex).
struct StremioMovieCardView: View {
    let item: StremioMeta
    let progress: CGFloat
    let onTap: () -> Void

    let itemWidth: CGFloat = 250
    let itemHeight: CGFloat = 380

    @FocusState private var isFocused: Bool

    init(item: StremioMeta, progress: CGFloat = 0, onTap: @escaping () -> Void) {
        self.item = item
        self.progress = progress
        self.onTap = onTap
    }

    var body: some View {
        VStack {
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    WebImage(url: URL(string: item.poster ?? ""), options: [.scaleDownLargeImages]) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(Color(red: 0.15, green: 0.17, blue: 0.2))
                    }
                    .frame(width: itemWidth, height: itemHeight)
                    .clipped()

                    if progress > 0 {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color("VArtThemeColor"))
                                .frame(width: itemWidth * progress, height: 8)
                                .position(x: (itemWidth * progress) / 2, y: itemHeight - 2)
                        }
                    }
                }
            }
            .buttonStyle(.card)
            .focused($isFocused)

            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(text: item.name, isFocused: isFocused)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)

                Text(item.type.capitalized)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#a0aab1"))
                    .lineLimit(1)
            }
            .frame(width: itemWidth, alignment: .leading)
            .padding(.top, 12)
        }
    }
}
