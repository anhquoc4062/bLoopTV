//
//  HeroBannerView.swift
//  bLoopTV
//
//  Created by Monster on 15/5/26.
//
import SwiftUI
import SDWebImageSwiftUI

struct HeroBannerView: View {
    let items: [PlexMetaData]
    var onSelect: (PlexMetaData) -> Void

    @State private var currentIndex: Int = 0
    @FocusState private var isButtonFocused: Bool
    
    private let autoScrollInterval: TimeInterval = 7

    var body: some View {
        // 1. Dùng mảng indices để tránh lỗi binding và đảm bảo mượt mà
        TabView(selection: $currentIndex) {
            ForEach(Array(items.indices), id: \.self) { index in
                let item = items[index]
                
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        
                        // HÌNH NỀN: Ép tràn toàn bộ khung hình Geo
                        backdropImage(for: item)
                            .frame(width: geo.size.width, height: geo.size.height)
                        
                        // OVERLAYS: Đảm bảo tràn theo nền
                        mainOverlays
                            .frame(width: geo.size.width, height: geo.size.height)
                        
                        // NỘI DUNG: Tự padding so với layout tràn màn hình
                        contentDetails(for: item)
                            .padding(.leading, 100) // Thụt lề trái chuẩn Apple TV
                            .padding(.bottom, 100)  // Thụt lề dưới để không sát mép nhựa TV
                    }
                }
                .tag(index).id(index)
                // QUAN TRỌNG: ignoresSafeArea nằm trong ForEach để mỗi trang đều tràn
                .ignoresSafeArea()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 900)
        .ignoresSafeArea() // Tràn hoàn toàn khỏi các lề mặc định của hệ điều hành
        // .onAppear(perform: startAutoScroll)
    }

    // MARK: - Backdrop
    @ViewBuilder
    private func backdropImage(for item: PlexMetaData) -> some View {
        let urlStr = item.imageSources?.coverArt ?? item.imageSources?.art ?? item.thumbnail
        
        WebImage(url: buildURL(urlStr, width: 2560, height: 1440))
            .resizable()
            .scaledToFill() // Quan trọng để ảnh không có khoảng trắng
            .overlay(Color.black.opacity(0.1))
            .clipped()
    }

    // MARK: - Overlays
    private var mainOverlays: some View {
        ZStack {
            // Gradient đáy
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: Color("BackgroundColor").opacity(0.85), location: 0.7),
                    .init(color: Color("BackgroundColor"), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Gradient trái (Dày hơn để bảo vệ nội dung text)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color("BackgroundColor").opacity(0.9), location: 0),
                    .init(color: Color("BackgroundColor").opacity(0.4), location: 0.3),
                    .init(color: .clear, location: 0.7)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: - Nội dung (Đã tối ưu font cho màn hình tràn)
    @ViewBuilder
    private func contentDetails(for item: PlexMetaData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            
            VStack(alignment: .leading, spacing: 5) {
                if let genre = item.genres?.first?.tag {
                    Text(genre.uppercased())
                        .font(.system(size: 24, weight: .bold)) // Tăng size cho TV
                        .foregroundStyle(.secondary)
                }
                
                Text(item.title)
                    .font(.system(size: 90, weight: .black)) // Title lớn cinematic
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 15)
            }

            if let tagline = item.summary ?? item.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: 1000, alignment: .leading)
                    .lineLimit(2)
            }

            HStack(spacing: 30) {
                Button(action: { onSelect(item) }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Phát")
                    }
                    .padding(.horizontal, 45)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.card)
                .focused($isButtonFocused)

                Button(action: { onSelect(item) }) {
                    Text("Chi tiết")
                        .padding(.horizontal, 45)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.card)
            }
            .padding(.top, 25)
            
            // Indicators
            HStack(spacing: 12) {
                ForEach(0..<items.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == currentIndex ? 40 : 12, height: 8)
                        .animation(.spring(), value: currentIndex)
                }
            }
            .padding(.top, 30)
        }
    }

    private func startAutoScroll() {
        // Chỉ chạy timer nếu chưa có
        Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            if !isButtonFocused {
                withAnimation(.easeInOut(duration: 1.0)) {
                    currentIndex = (currentIndex + 1) % items.count
                }
            }
        }
    }

    private func buildURL(_ path: String?, width: Int, height: Int) -> URL? {
        guard let path = path else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return PlexAPI.shared.getPosterTranscodeURL(url: path, width: width, height: height)
    }
}
