//
//  ActorSectionView.swift
//  bLoopTV
//
//  Created by Monster on 29/6/26.
//

import SwiftUI

struct ActorSectionView: View {
    let listRole: [PlexActor]

    var body: some View {
        // if !listRole.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Diễn viên")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 28) {
                        ForEach(listRole) { role in
                            ActorCardView(role: role)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .focusSection()
        // }
    }
}
