//
//  ContentView.swift
//  bLoopTV
//
//  Created by Monster on 20/1/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject var navPathManager = NavigationPathManager()
    @ObservedObject var sourcePreference = HomeSourcePreference.shared
    var body: some View {
        VStack {
            
            NavigationStack(path: $navPathManager.path) {
                rootView
                    .navigationBarHidden(true)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        buildDestination(destination)
                    }
            }
            .environmentObject(navPathManager)
            .navigationViewStyle(StackNavigationViewStyle())
            .toolbar(.hidden, for: .tabBar)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // Bấm vào Continue Watching ở Top Shelf (ngoài Home Screen) mở app bằng URL dạng
    // "blooptv://continueWatching?source=plex|stremio&id=...&title=...&poster=...&type=..."
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "blooptv", url.host == "continueWatching",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        func value(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        guard let source = value("source"), let id = value("id") else { return }
        let title = value("title") ?? ""
        let poster = value("poster")
        let background = value("background")
        let type = value("type") ?? ""

        switch source {
        case "plex":
            let guid = value("guid")
            let art = value("art")
            let metadata = PlexMetaData.placeholder(id: id, title: title, poster: poster, background: "", type: type, guid: guid, art: art)
            navPathManager.push(.movieDetail(metadata: metadata, isDiscover: false))

        case "stremio":
            let item = StremioMeta(id: id, type: type, name: title, poster: poster, background: background)
            Task {
                guard let authKey = StremioAccountAPI.shared.authKey,
                      let addons = try? await StremioAccountAPI.shared.fetchAddonCollection(authKey: authKey) else { return }
                await MainActor.run {
                    navPathManager.push(.stremioMovieDetail(item: item, addons: addons))
                }
            }

        default:
            break
        }
    }

    // Mở app vào đúng nguồn đã chọn lần cuối: Stremio (nếu còn đăng nhập) hoặc Plex HomeView như mặc định.
    @ViewBuilder
    private var rootView: some View {
        if sourcePreference.current == .stremio && StremioAccountAPI.shared.authKey != nil {
            StremioAccountHomeView()
        } else {
            HomeView()
        }
    }

    @ViewBuilder
    private func buildDestination(_ destination: NavigationDestination) -> some View {
        switch destination {
        case .movieDetail(let metadata, let isDiscover):
            MovieDetailView(metadata: metadata, isDiscover: isDiscover)
                .id(metadata.id)
        case .videoPlayer(let playbackData):
            VideoPlayerView(playbackData: playbackData)
        case .searchPage:
            SearchView()
        case .stremioLogin:
            StremioLoginView()
        case .stremioAccountHome:
            StremioAccountHomeView()
        case .stremioMovieDetail(let item, let addons):
            StremioMovieDetailView(item: item, addons: addons)
        case .stremioSearch(let addons):
            StremioSearchView(addons: addons)
//        case .videoPlayer(let data):
//                PlayerContainer(
//                    view: VideoPlayerView(playbackData: data)
//                )
            
//        case .collection(let title, let hubKey, let isDiscover, let hasFilteredHeader):
//            CollectionView(sectionTitle: title, hubKey: hubKey, isDiscover: isDiscover, hasFilteredHeader: hasFilteredHeader)
//            
//        case .actorDetail(let actor):
//            ActorDetailView(actor: actor)
//                .id(actor.id)
//
//            
//        case .discoverPage(let title, let hubKey, let showBackButton):
//            DiscoverView(title: title, hubKey: hubKey, showBackButton: showBackButton)
//                .navigationBarHidden(true)
//            
//        case .watchTogetherRoom(let room):
//            WatchTogetherRoomView(room: room)
//                .navigationBarHidden(true)
//            
//        case .filterMovie(let filterQuery):
//            FilterMoviesView(filterQuery: filterQuery)
//                .navigationBarHidden(true)
//            
//        case .notifications:
//            NotificationView()
//                .navigationBarHidden(true)
//            
//        case .notificationDetail(let notification):
//            NotificationDetailView(notification: notification)
//                .navigationBarHidden(true)
        default:
            EmptyView()
        }
    }
}
