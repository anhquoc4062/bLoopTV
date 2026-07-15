//
//  HomeView.swift
//  bLoopTV
//
//  Created by Monster on 20/1/26.
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI


enum HomeTab: String, CaseIterable {
    case recommended = "Recommended"
    case movies = "Movies"
    case shows = "Shows"
    case anime = "Anime"
    case documentaries = "Documentaries"
    
    var title: String {
       switch self {
           case .recommended: return "Gợi ý"
           case .movies: return "Phim lẻ"
           case .shows: return "Phim bộ"
           case .anime: return "Hoạt hình"
           case .documentaries: return "Tài liệu"
       }
   }
}
struct HomeView: View {
    @EnvironmentObject var navPathManager: NavigationPathManager
    @StateObject var homeViewModel = HomeViewModel()
    @ObservedObject var plexAPI = PlexAPI.shared
    
    // Định nghĩa các vùng có thể focus
    enum FocusArea: Hashable {
        case topBar    // Chứa nút Server và Search
        case movieGrid // Chứa danh sách phim
    }
    
    // Biến điều khiển focus mặc định
    @FocusState private var focusedArea: FocusArea?
    
    @State private var visibleLibraryIds: Set<String> = []
    @State private var hasAppearedOnce = false
    @State var currentHomeTab: HomeTab = .recommended
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // HERO BANNER tràn toàn màn hình
                ZStack(alignment: .top) {
                    // 1. Banner nền
                    if !homeViewModel.featuredMetadata.isEmpty {
                        HeroBannerView(items: homeViewModel.featuredMetadata) { meta in
                            navPathManager.push(.movieDetail(metadata: meta, isDiscover: false))
                        }.focusSection()
                        .frame(height: 900)
                    }

                    // 2. Top Bar đè lên Banner
                    topNavigationBar
                }
                
                // NỘI DUNG DƯỚI BANNER
                LazyVStack(alignment: .leading, spacing: 30) {

                    // Continue Watching
                    ForEach(homeViewModel.continueWatchingHub, id: \.id) { hub in
                        SectionView(
                            sectionTitle: "Xem Tiếp",
                            hubKey: "continueWatching",
                            metadatas: hub.metadatas ?? [],
                            isLandscapeSection: true,
                            isDiscover: false
                        )
                        .focused($focusedArea, equals: .movieGrid)
                        .focusSection()
                    }

                    // Libraries & Collections
                    ForEach(homeViewModel.libraries(for: currentHomeTab), id: \.id) { library in
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                if !visibleLibraryIds.contains(library.id) {
                                    visibleLibraryIds.insert(library.id)
                                    homeViewModel.fetchPinCollectionByLibraryId(id: library.id)
                                }
                            }

                        let collections = homeViewModel.homeCollectionsByLibrary[library.id] ?? []
                        ForEach(collections, id: \.id) { collection in
                            sectionView(title: collection.title, metadatas: collection.metadatas ?? [], hubKey: collection.key)
                                .focusSection()
                        }
                    }
                }
                .padding(.vertical)
                .padding(.top, -30)
            }
        }.edgesIgnoringSafeArea(.top)
        .background(Color("BackgroundColor"))
        .onAppear {
            if focusedArea == nil { focusedArea = .movieGrid }
            refreshData()
        }
    }

    // MARK: - Component: Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 30) {
            // Nút Tìm Kiếm
            Button(action: { navPathManager.push(.searchPage) }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Tìm kiếm")
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
            }
            .buttonStyle(.card) // Sử dụng .card để có hiệu ứng focus nổi lên trên TV

            // Menu chọn Server
            ServerSwitcherMenu(onPlexServerReselected: resetAndRefresh)

            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.top, 60)
        .edgesIgnoringSafeArea(.all)
        .background(
            // Gradient mờ ở đỉnh để làm nổi bật nút nếu ảnh Banner quá sáng
            LinearGradient(
                colors: [Color.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            ).frame(maxWidth: .infinity)
            .frame(height: 200)
            .edgesIgnoringSafeArea(.horizontal)
            .allowsHitTesting(false)
        )
    }

    // MARK: - Helper Methods
    
    private func resetAndRefresh() {
        visibleLibraryIds.removeAll()
        refreshData()
    }
    
    private func refreshData() {
        homeViewModel.fetchContinueWatchingHub()
        homeViewModel.fetchLibraries()
        homeViewModel.fetchRecommendationMetadatas()
    }
    
    private func fetchPoster(urlString: String?, isLandscape: Bool = false) -> URL {
        if let url = urlString {
            return PlexAPI.shared.getPosterTranscodeURL(
                url: url,
                width: isLandscape ? 647 : 480,
                height: isLandscape ? 432 : 960
            ) ?? URL(string: "https://example.com/fallback.jpg")!
        }
        return URL(string: "https://example.com/fallback.jpg")!
    }
    
    @ViewBuilder
    func sectionView(title: String, metadatas: [PlexMetaData], hubKey: String) -> some View {
        SectionView(sectionTitle: title, hubKey: hubKey, metadatas: metadatas, isLandscapeSection: false, isDiscover: false)
    }
}
