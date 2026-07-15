//
//  StremioSectionView.swift
//  bLoopTV
//

import SwiftUI

/// Đồng bộ style với SectionView (Views/Component/SectionView) nhưng dùng [StremioMeta] thay vì [PlexMetaData].
struct StremioSectionView: View {
    let sectionTitle: String
    let items: [StremioMeta]
    let progressForItem: (StremioMeta) -> CGFloat
    let onTapItem: (StremioMeta) -> Void

    init(
        sectionTitle: String,
        items: [StremioMeta],
        progressForItem: @escaping (StremioMeta) -> CGFloat = { _ in 0 },
        onTapItem: @escaping (StremioMeta) -> Void
    ) {
        self.sectionTitle = sectionTitle
        self.items = items
        self.progressForItem = progressForItem
        self.onTapItem = onTapItem
    }

    var body: some View {
        if !items.isEmpty {
            HStack(alignment: .center, spacing: 20) {
                Rectangle()
                    .fill(Color("VArtThemeColor"))
                    .frame(width: 8, height: 25)

                Text(sectionTitle)
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 50) {
                    ForEach(items) { item in
                        StremioMovieCardView(item: item, progress: progressForItem(item)) {
                            onTapItem(item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
        }
    }
}
