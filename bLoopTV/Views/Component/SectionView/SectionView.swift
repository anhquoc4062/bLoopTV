//
//  SectionView.swift
//  bLoopTV
//
//  Created by Monster on 20/1/26.
//

import SwiftUI

struct SectionView: View {
    
    let sectionTitle: String
    let hubKey: String
    let metadatas: [PlexMetaData]
    let isLandscapeSection: Bool?
    let isDiscover: Bool?
    let itemHeight: CGFloat = 380
    let itemWidth: CGFloat = 250

    
    @State private var showDetail = false
    @State private var selectedMetadata: PlexMetaData? = nil

    
    var body: some View {
        if metadatas.count > 0 {
            HStack(alignment: .center, spacing: 20) {
                Rectangle()
                    .fill(Color("VArtThemeColor"))
                    .frame(width: 8, height: 25)
                // .padding(.leading, 15)
                
                Text(cleanSectionTitle(sectionTitle))
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 50) {
                    ForEach(metadatas) { metadata in
                        
                        MovieCardView(metadata: metadata, isLandscape: isLandscapeSection ?? false, isContinueWatching: hubKey == "continueWatching")
                    }
                }
                .padding(.horizontal)
                .padding(.top, isLandscapeSection ?? false ? 20 : 24)
            }
            // .frame(height: isLandscapeSection == true ? (itemWidth + 90) : (itemHeight + 50))
        }
    }
    
    func cleanSectionTitle(_ title: String) -> String {
        return title.split(separator: "_").first.map(String.init) ?? title
    }
}
