//
//  HomeTopBar.swift
//  bLoopTV
//
//  Thanh header dùng chung cho Home của Plex và Stremio: cùng padding + lớp gradient tối ở đỉnh để nút
//  vẫn đọc được khi banner phía sau quá sáng. Nội dung nút do từng Home tự truyền vào.
//

import SwiftUI

struct HomeTopBar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 30) {
            leading

            Spacer()

            trailing
        }
        .padding(.horizontal, 80)
        .padding(.top, 60)
        .edgesIgnoringSafeArea(.all)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .edgesIgnoringSafeArea(.horizontal)
            .allowsHitTesting(false)
        )
    }
}

extension HomeTopBar where Trailing == EmptyView {
    init(@ViewBuilder leading: () -> Leading) {
        self.init(leading: leading, trailing: { EmptyView() })
    }
}
