//
//  ActorCardView.swift
//  bLoopTV
//
//  Created by Monster on 29/6/26.
//

import SwiftUI
import SDWebImageSwiftUI

struct ActorCardView: View {
    @EnvironmentObject var navManager: NavigationPathManager
    let role: PlexActor

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Button(action: {
                navManager.push(.actorDetail(actor: role))
            }) {
                WebImage(
                    url: URL(string: role.thumbnail ?? ""),
                    options: [.scaleDownLargeImages]
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.1)
                }
                .frame(width: 140, height: 140)
            }
            .buttonStyle(.card)
            .focused($isFocused)
            
            Text(role.tag)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let character = role.role, !character.isEmpty {
                Text(character)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(width: 160)


    }
}
