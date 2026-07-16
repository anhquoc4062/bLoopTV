//
//  HomeViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 23/5/25.
//
import Foundation
import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    
    @Published var libraries: [PlexLibrary] = []
    @Published var moviesLibraries: [PlexLibrary] = []
    @Published var showsLibraries: [PlexLibrary] = []
    @Published var animeLibraries: [PlexLibrary] = []
    @Published var documentariesLibraries: [PlexLibrary] = []
    
    @Published var homeCollectionsByLibrary: [String: [PlexHomeCollection]] = [:]
    @Published var continueWatchingHub: [PlexHomeCollection] = []
    @Published var documentariesHub: [String: [PlexMetaData]] = [:]
    @Published var tags: [PlexTag] = []
    
    @Published var featuredMetadata: [PlexMetaData] = []
    @Published var featuredMetadataPlaceholder: [PlexMetaData] = []
    @Published var seasonalMetadata: [PlexMetaData] = []
    @Published var recommendationMetadata: [PlexMetaData] = []
    @Published var errorMessage: String?
    
    private let collectionsCache = NSCache<NSString, NSArray>()
    
    init() {
        
    }
    
    func loadUserDataFromDefaults() -> PlexUserData? {
        guard let data = UserDefaults.standard.data(forKey: "userData") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(PlexUserData.self, from: data)
        } catch {
            print("Failed to decode user data: \(error)")
            return nil
        }
    }
    
    func libraries(for tab: HomeTab) -> [PlexLibrary] {
        switch tab {
        case .recommended:
            return libraries
        case .movies:
            return libraries.filter { $0.type == "movie" && !$0.title.localizedCaseInsensitiveContains("Animation") && !$0.title.localizedCaseInsensitiveContains("Doc-") }
        case .shows:
            return libraries.filter { $0.type == "show" && !$0.title.localizedCaseInsensitiveContains("Animation") && !$0.title.localizedCaseInsensitiveContains("Doc-") }
        case .anime:
            return libraries.filter { $0.type == "show" && $0.title.localizedCaseInsensitiveContains("Animation") }
        case .documentaries:
            return libraries.filter { $0.title.localizedCaseInsensitiveContains("Doc-") }
        }
    }
    
    func fetchLibraries() {
        PlexAPI.shared.fetchLibraries() { result in
            switch result {
            case .success(let libraries):
                let filtered = libraries.filter { library in
                    library.type == "movie" || library.type == "show"
                }
                DispatchQueue.main.async {
                    self.libraries = filtered
                    let filteredIds = self.libraries.map { $0.id }
                    self.moviesLibraries = self.libraries
                        .filter { $0.type == "movie" && !$0.title.localizedCaseInsensitiveContains("Animation") && !$0.title.localizedCaseInsensitiveContains("Doc-") }
                    
                    self.showsLibraries = self.libraries
                        .filter { $0.type == "show" && !$0.title.localizedCaseInsensitiveContains("Animation") && !$0.title.localizedCaseInsensitiveContains("Doc-") }
                    
                    self.animeLibraries = self.libraries
                        .filter { $0.type == "show" && $0.title.localizedCaseInsensitiveContains("Animation") }
                    
                    self.documentariesLibraries = self.libraries
                        .filter { $0.title.localizedCaseInsensitiveContains("Doc-") }

                    
                    print("filteredIds: \(filteredIds)")
                    UserDefaults.standard.set(filteredIds, forKey: "savedLibraryIds")
                }
            case .failure(let error):
                print(error)
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchPinCollectionByLibraryId(id: String) {
        PlexAPI.shared.fetchPinCollectionByLibraryId(libraryId: id) { result in
            switch result {
            case .success(let homeCollections):
                // print(homeCollections)
                let collections: [PlexHomeCollection] = homeCollections.filter {
                    !$0.title.contains("🔥") && !$0.title.contains("<season>")
                }
                let featuredCollections: [PlexHomeCollection] = homeCollections.filter {
                    $0.title.contains("🔥") || $0.title.contains("Recently Added in PHIM LẺ") || $0.title.contains("Recently Added in ANIME") || $0.title.contains("Recently Added in PHIM HOẠT")
                }
                let seasonCollections: [PlexHomeCollection] = homeCollections.filter {
                    $0.title.contains("<season>")
                }
//                self.homeCollectionsByLibrary[id]?.removeAll()
//                self.homeCollectionsByLibrary[id] = collections
                self.homeCollectionsByLibrary[id] = collections
                DispatchQueue.main.async {
                    for collection in featuredCollections {
                        if let metadatas = collection.metadatas {
                            self.featuredMetadata.append(contentsOf: metadatas)
                        }
                    }
                    self.featuredMetadata = self.featuredMetadata.sorted(by: {
                        
                        guard let lhsDate = $0.addedAt else { return false }
                        guard let rhsDate = $1.addedAt else { return true }
                        return lhsDate > rhsDate
                    })
                    .prefix(20)
                    .map { $0 }
                    
                    for collection in seasonCollections {
                        if let metadatas = collection.metadatas {
                            self.seasonalMetadata.append(contentsOf: metadatas)
                        }
                    }
                    self.seasonalMetadata = self.seasonalMetadata.sorted(by: {
                        
                        guard let lhsRating = $0.audienceRating else { return false }
                        guard let rhsRating = $1.audienceRating else { return true }
                        return lhsRating > rhsRating
                    })
                    .map { $0 }
                }
                
            case .failure(let error):
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
            
        }
        
        
    }
    
    func fetchHubsByLibraryId(id: String, isAnimeTab: Bool = false, isDocumentariesTab: Bool = false) {
        
        PlexAPI.shared.fetchHubsByLibraryId(libraryId: id) { result in
            switch result {
            case .success(let homeCollections):
                let collections: [PlexHomeCollection] = homeCollections.filter {
                    (isAnimeTab ? !$0.title.contains("Thịnh Hành") : !$0.title.contains("🔥")) && !$0.title.contains("Continue Watching") && !$0.title.contains("<season>")
                }
                let featuredCollections: [PlexHomeCollection] = homeCollections.filter {
                    isAnimeTab ? $0.title.contains("Thịnh Hành") : $0.title.contains("🔥")
                }
                
                
                if isDocumentariesTab {
                    for collection in collections {
                        if var checkedCollectionByTitle = self.documentariesHub[collection.title],
                           let metadatas = collection.metadatas
                        {
                            checkedCollectionByTitle.append(contentsOf: metadatas)
                            
                            checkedCollectionByTitle = checkedCollectionByTitle.sorted(by: {
                                
                                guard let lhsDate = $0.addedAt else { return false }
                                guard let rhsDate = $1.addedAt else { return true }
                                return lhsDate > rhsDate
                            })
                            .map { $0 }
                            self.documentariesHub[collection.title] = checkedCollectionByTitle
                        } else {
                            self.documentariesHub[collection.title] = collection.metadatas
                        }
                    }
                } else {
                    self.homeCollectionsByLibrary[id] = collections
                }
                DispatchQueue.main.async {
                    for collection in featuredCollections {
                        if let metadatas = collection.metadatas {
                            self.featuredMetadata.append(contentsOf: metadatas)
                        }
                    }
                    self.featuredMetadata = self.featuredMetadata.sorted(by: {
                        
                        guard let lhsDate = $0.addedAt else { return false }
                        guard let rhsDate = $1.addedAt else { return true }
                        return lhsDate > rhsDate
                    })
                    .prefix(20)
                    .map { $0 }
                }
                
            case .failure(let error):
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
            
        }
        
        
    }
    
    func fetchContinueWatchingHub() {
        PlexAPI.shared.fetchContinueWatchingHub() { result in
            switch result {
            case .success(let continueWatchingHub):
                DispatchQueue.main.async {
                    self.continueWatchingHub = continueWatchingHub.map { hub in
                        var updatedHub = hub

                        updatedHub.metadatas = hub.metadatas?.sorted {
                            ($0.lastViewedAt ?? 0) > ($1.lastViewedAt ?? 0)
                        }

                        return updatedHub
                    }

                    self.syncContinueWatchingToTopShelf()
                }
            case .failure(let error):
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
        
        
    }
    
    /// Đưa Continue Watching của server Plex đang chọn ra Top Shelf ngoài Home Screen (giống Plex/Netflix).
    /// Chỉ đồng bộ khi Plex đang là nguồn đang dùng — tránh đè lên Top Shelf khi người dùng đang ở Stremio.
    private func syncContinueWatchingToTopShelf() {
        guard HomeSourcePreference.shared.current == .plex else { return }

        let items: [SharedContinueWatchingItem] = continueWatchingHub
            .flatMap { $0.metadatas ?? [] }
            .prefix(10)
            .map { metadata in
                let isEpisode = metadata.type == "episode"
                // Với tập phim, đi thẳng vào ID của cả series (grandParentId) — giống cách app đã làm khi
                // bấm vào thẻ Xem Tiếp bình thường (MovieDetailView tự fetch theo
                // grandParentId ?? parentId ?? id, nên fetch bằng id tập lẻ sẽ sai/không load được).
                let deepLinkId = isEpisode ? (metadata.grandParentId ?? metadata.id) : metadata.id
                let deepLinkType = isEpisode ? "show" : metadata.type

                // Tập phim dùng poster của series (grandparentThumb) cho khớp dạng poster của Top Shelf;
                // thiếu thì lùi về art/poster của tập. Phim lẻ dùng "poster" như cũ.
                let imageSource = isEpisode
                    ? (metadata.grandparentThumb ?? metadata.thumbnail ?? metadata.poster)
                    : metadata.poster
                let posterURL = PlexAPI.shared.getPosterTranscodeURL(url: imageSource ?? "", width: 480, height: 720)
                let title = isEpisode ? (metadata.grandParentTitle ?? metadata.title) : metadata.title

                var deepLink = URLComponents(string: "blooptv://continueWatching")!
                var queryItems = [
                    URLQueryItem(name: "source", value: "plex"),
                    URLQueryItem(name: "id", value: deepLinkId),
                    URLQueryItem(name: "title", value: title),
                    URLQueryItem(name: "poster", value: imageSource ?? ""),
                    URLQueryItem(name: "type", value: deepLinkType),
                    URLQueryItem(name: "art", value: imageSource ?? "")
                ]
                // guid dùng để trang detail tự fetch ảnh nền/logo thật — chỉ đáng tin khi id đích và guid
                // cùng 1 entity (không dùng cho episode vì đã đổi id sang grandParentId của cả series).
                if !isEpisode, let guid = metadata.guid {
                    queryItems.append(URLQueryItem(name: "guid", value: guid))
                }
                deepLink.queryItems = queryItems

                return SharedContinueWatchingItem(
                    id: "plex-\(metadata.id)",
                    title: title,
                    subtitle: nil,
                    posterURLString: posterURL?.absoluteString,
                    deepLinkURLString: deepLink.url?.absoluteString ?? ""
                )
            }

        ContinueWatchingSync.write(items)
    }

    func fetchTags(libraryId: String) {
        PlexAPI.shared.fetchTags(libraryId: libraryId) { result in
            switch result {
            case .success(let tags): 
                DispatchQueue.main.async {
                    // self.continueWatchingHub = continueWatchingHub
                    let suffix = "_<tag>"
                    let taggedItems = tags
                        .filter { $0.title.hasSuffix(suffix) == true }
                        .map { original -> PlexTag in
                            var copy = original
                            copy.tagName = String(original.title.dropLast(suffix.count))
                            return copy
                        }
                    
                    self.tags = taggedItems
                    
                    let recommendedTaggedItems = tags
                        .filter { $0.title.localizedCaseInsensitiveContains("Dành cho") }
                        .map { original -> PlexTag in
                            var copy = original
                            copy.tagName = String(original.title.dropLast(suffix.count))
                            return copy
                        }
                    
                    
                }
            case .failure(let error):
                print("Error from fetchTags: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchUserData(completion: @escaping (PlexUserData) -> Void = { _ in }) {
        
        UserAPI.shared.fetchUserInformation() { result in
            switch result {
            case .success(let userData):
                completion(userData)
            case .failure(let error):
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
        
        
    }
    
    func fetchSeasonalMetadata(libraryId: String) {
        PlexAPI.shared.fetchSeasonalMetadatas(libraryId: libraryId) { result in
            switch result {
            case .success(let seasonalMetadata):
                DispatchQueue.main.async {
                    self.seasonalMetadata = seasonalMetadata
                }
            case .failure(let error):
                print("Error from fetchSeasonalMetadata: \(error.localizedDescription)")
            }
        }
    }
    
    func clearMemory() {
//        homeCollectionsByLibrary.removeAll()
//        continueWatchingHub.removeAll()
//
//        libraries.removeAll()
//        moviesLibraries.removeAll()
//        showsLibraries.removeAll()
//        animeLibraries.removeAll()

        errorMessage = nil
    }
    
    func fetchCategories(libraryId: String, completion: (() -> Void)? = nil) {
        let cacheKey = "cachedCategories_\(libraryId)"

        PlexAPI.shared.fetchCategories(libraryId: libraryId) { result in
            switch result {
            case .success(let categoriesFromServer):
                DispatchQueue.main.async {
                    if let oldData = UserDefaults.standard.data(forKey: cacheKey),
                       let oldCategories = try? JSONDecoder().decode([PlexCategory].self, from: oldData) {

                        var dict = Dictionary(uniqueKeysWithValues: oldCategories.map { ($0.id, $0) })
                        for cat in categoriesFromServer {
                            dict[cat.id] = cat
                        }
                        
                        let serverIds = Set(categoriesFromServer.map { $0.id })
                        dict = dict.filter { serverIds.contains($0.key) }

                        let updatedCategories = Array(dict.values)
                        if let encoded = try? JSONEncoder().encode(updatedCategories) {
                            UserDefaults.standard.set(encoded, forKey: cacheKey)
                        }
                    } else {
                        if let encoded = try? JSONEncoder().encode(categoriesFromServer) {
                            UserDefaults.standard.set(encoded, forKey: cacheKey)
                        }
                    }

                    completion?()
                }
            case .failure(let error):
                print("error: \(error)")
                DispatchQueue.main.async { completion?() }
            }
        }
    }
    
    func fetchRecommendationMetadatas() {
        if let userCached = loadUserDataFromDefaults() {
            print("userCached from fetchRecommendationMetadatas: \(userCached)")
            PlexAPI.shared.fetchMetadatasByHubKey(
                key: "/library/all?sort=addedAt:desc&label=RecommendedMovies_\(userCached.username ?? ""),RecommendedShows_\(userCached.username ?? "")",
                offset: 0,
                size: 50,
                isDiscover: false
            ) { result in
                switch result {
                case .success(let metadatas):
                    DispatchQueue.main.async {
                        self.recommendationMetadata = metadatas
                    }
                case .failure(let error):
                    print("Error from fetchRecommendationMetadatas: \(error.localizedDescription)")
                }
            }
        } else {
            print("Dont have user data")
        }
    }
}
