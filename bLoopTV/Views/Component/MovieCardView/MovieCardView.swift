//
//  MovieCardView.swift
//  bLoopTV
//
//  Created by Monster on 20/1/26.
//
import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

struct MovieCardView: View {
    @EnvironmentObject var navManager: NavigationPathManager
    let metadata: PlexMetaData
    let isLandscape: Bool
    let isContinueWatching: Bool
    let itemWidth: CGFloat = 250
    let itemHeight: CGFloat = 380
    
    @State private var posterURL: URL?
    @FocusState private var isFocused: Bool
    
    private var viewProgress: CGFloat {
        guard let duration = metadata.duration, duration > 0,
              let offset = metadata.viewOffset else { return 0 }
        return CGFloat(offset) / CGFloat(duration)
    }

    var body: some View {
        VStack {
            Button(action: {
                navManager.push(
                    .movieDetail(
                        metadata: metadata,
                        isDiscover: false
                    )
                )
            }) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        WebImage(url: posterURL, options: [.scaleDownLargeImages]) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .foregroundColor(Color(red: 0.15, green: 0.17, blue: 0.2))
                        }
                        .frame(
                            width: isLandscape ? itemHeight + 70 : itemWidth,
                            height: isLandscape ? itemWidth + 50 : itemHeight
                        )
                        .clipped()
                        
                        if isContinueWatching,
                           let librarySectionTitle = metadata.librarySectionTitle {
                            Text(librarySectionTitle)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .offset(x: 20, y: itemWidth - 12)
                        }
                        
                        if viewProgress > 0 {
                            GeometryReader { geometry in
                                let width = isLandscape ? itemHeight + 70 : itemWidth
                                let height = isLandscape ? itemWidth + 50 : itemHeight
                                Rectangle()
                                    .fill(Color("VArtThemeColor"))
                                    .frame(width: width * viewProgress, height: 8)
                                    .position(x: (width * viewProgress) / 2, y: height - 2)
                            }
                        }
                    }
                    
                }
                
                
            }
            .buttonStyle(.card)
            .focused($isFocused)
            
            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: metadata.type == "episode" ? (metadata.grandParentTitle ?? metadata.title) : metadata.title,
                    isFocused: isFocused
                )
                .font(.caption)
                .bold()
                .foregroundColor(.white)
                
                Text(getSubtitle())
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#a0aab1"))
                    .lineLimit(1)
            }
            .frame(width: isLandscape ? itemHeight + 70 : itemWidth, alignment: .leading)
            .padding(.top, 12)
        }
        .onAppear {
            fetchPoster(urlString: isLandscape ? (metadata.thumbnail ?? metadata.poster ?? "") : (metadata.poster ?? ""))
        }
    }
    
    private func fetchPoster(urlString: String) {
        if let plexURL = PlexAPI.shared.getPosterTranscodeURL(
            url: urlString,
            width: isLandscape ? 647 : 432,
            height: isLandscape ? 432 : 647,
        ) {
            posterURL = plexURL
        }
    }
    
    private func getSubtitle() -> String {
        if metadata.type == "episode" {
            return "M\(metadata.seasonIndex ?? 1):T\(metadata.episodeIndex ?? 1) - \(metadata.title)"
        } else if metadata.type == "show" {
            if let childCount = metadata.childCount {
                return "\(childCount > 1 ? "\(childCount) mùa" : "\(metadata.leafCount ?? 1) tập")"
            } else {
                return "1 tập"
            }
        } else {
            return metadata.year ?? "1970"
        }
    }
}

struct MarqueeText: View {
    let text: String
    let isFocused: Bool
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: isFocused, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                self.textWidth = textGeo.size.width
                            }
                    }
                )
                .offset(x: offset)
                .id(isFocused)
                .onAppear {
                    self.containerWidth = geo.size.width
                }
        }
        .frame(height: 30)
        .clipped()
        .onChange(of: isFocused) { focused in
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if textWidth > containerWidth {
                        let duration = Double((textWidth - containerWidth) / 40)
                        withAnimation(Animation.linear(duration: duration).repeatCount(1)) {
                            offset = -(textWidth - containerWidth)
                        }
                    }
                }
            } else {
                offset = 0
            }
        }
    }
}
