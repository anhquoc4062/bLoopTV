//
//  MovieDetailViewModel.swift
//  Media App For Plex
//
//  Created by Monster on 25/5/25.
//

import Foundation
import Combine


struct MetadataSelected: Identifiable {
    let id: String
    let viewOffset: Int
    let duration: Int
    let episodeIndex: Int?
    let seasonIndex: Int?
    let type: String
    let lastViewedAt: Int?
    let listVersion: [PlexMedia]
    let listMarker: [PlexMarker]
    
    var listVersionFiltered: [PlexMedia] {
        listVersion.filter { version in
            version.parts.first?.accessible ?? true
        }
    }
}

@MainActor
class MovieDetailViewModel: ObservableObject {
    @Published var thumbnailURL: URL?
    @Published var localThumbnailURL: URL?
    @Published var logoURL: URL?
    @Published var metaDataDetail: PlexMetaDataDetail?
    @Published var isWatched: Bool = false
    @Published var selectedMetadata: MetadataSelected?
    @Published var selectedSubtitle: PlexMediaPartStream?
    @Published var selectedAudio: PlexMediaPartStream?
    @Published var episodes: [Episode]?

    func fetchThumbnail(url: String?) {
        localThumbnailURL = PlexAPI.shared.getPosterTranscodeURL(url: url, width: 1280, height: 800)
    }
    
    func fetchMetadataDetailAsync(id: String, isDiscover: Bool = false) async {
        do {
            let metadataDetail = try await PlexAPI.shared.fetchMetadataDetailAsync(id: id, isDiscover: isDiscover)
            // DispatchQueue.main.async {
                self.metaDataDetail = metadataDetail
//                if let onDeck = metadataDetail.onDeck {
//                    self.selectedMetadata = MetadataSelected(
//                        id: onDeck.metadata.id,
//                        viewOffset: onDeck.metadata.viewOffset ?? 0,
//                        duration: onDeck.metadata.duration,
//                        episodeIndex: onDeck.metadata.episodeIndex ?? 1,
//                        seasonIndex: onDeck.metadata.seasonIndex ?? 1,
//                        type: onDeck.metadata.type,
//                        lastViewedAt: onDeck.metadata.lastViewedAt,
//                        listVersion: onDeck.metadata.medias ?? [],
//                        listMarker: onDeck.metadata.markers ?? [],
//                    )
//                } else {
                if let medias = metadataDetail.medias, !medias.isEmpty {
                        self.selectedMetadata = MetadataSelected(
                            id: metadataDetail.id,
                            viewOffset: metadataDetail.viewOffset ?? 0,
                            duration: metadataDetail.duration,
                            episodeIndex: metadataDetail.episodeIndex ?? 1,
                            seasonIndex: metadataDetail.seasonIndex ?? 1,
                            type: metadataDetail.type,
                            lastViewedAt: metadataDetail.lastViewedAt,
                            listVersion: metadataDetail.medias ?? [],
                            listMarker: metadataDetail.markers ?? []
                        )
                    } else {
                        PlexAPI.shared.fetchAllLeaves(id: id) { result in
                            switch result {
                            case .success(let metadatas):
                                var episodes: [Episode] = []
                                for metadata in metadatas {
                                    episodes.append(Episode(
                                        id: metadata.id,
                                        title: metadata.title,
                                        grandTitle: metadata.grandparentTitle ?? "",
                                        thumbnailURL: PlexAPI.shared.getPosterTranscodeURL(url: metadata.poster, width: 900, height: 600),
                                        episodeIndex: metadata.episodeIndex ?? 1,
                                        seasonIndex: metadata.seasonIndex ?? 1,
                                        summary: metadata.summary,
                                        isWatched: metadata.lastViewedAt != nil && (metadata.viewOffset == nil || metadata.viewOffset == 0) ? true : false,
                                        viewOffset: metadata.viewOffset ?? 0,
                                        type: metadata.type,
                                        duration: metadata.duration,
                                        originallyAvailableAt: metadata.originallyAvailableAt,
                                        medias: metadata.medias ?? []
                                    ))
                                }
                                
                                if let episodeOndeck = episodes.first(where: { $0.id == metadataDetail.onDeck?.metadata.id }) {
                                    Task {
                                        await self.updateSelectedMetadataByEpisode(episodeData: episodeOndeck)
                                    }
                                } else if let firstUnwatchEpisode = episodes.first(where: { !$0.isWatched }) {
                                    Task {
                                        await self.updateSelectedMetadataByEpisode(episodeData: firstUnwatchEpisode)
                                    }
                                } else if let firstEpisode = episodes.first {
                                    Task {
                                        await self.updateSelectedMetadataByEpisode(episodeData: firstEpisode)
                                    }
                                }
                                
                            case .failure(let error):
                                print("Error from fetchAllLeaves: \(error.localizedDescription)")
                            }
                        }
                    }
                // }
                
                self.updateFlagsAfterSelected()
            // }
        } catch {
            print("error fetch detail id \(id):", error)
        }
    }
    
    func fetchMetadataFromDiscoverAsync(id: String) async -> PlexMetaDataDetail? {
        do {
            let metadataDetail = try await PlexAPI.shared.fetchMetadataDetailAsync(id: id, isDiscover: true)
            return metadataDetail
        } catch {
            print("error fetch detail of id \(id):", error)
        }
        return nil
    }
    
    func updateSelectedMetadataByEpisode(episodeData: Episode) async {
        do {
            let episodeDetailData = try await PlexAPI.shared.fetchMetadataDetailAsync(id: episodeData.id)
            DispatchQueue.main.async {
                print("updated here??")
                self.selectedMetadata = MetadataSelected(
                    id: episodeDetailData.id,
                    viewOffset: episodeDetailData.viewOffset ?? 0,
                    duration: episodeDetailData.duration,
                    episodeIndex: episodeDetailData.episodeIndex ?? 1,
                    seasonIndex: episodeDetailData.seasonIndex ?? 1,
                    type: episodeDetailData.type,
                    lastViewedAt: episodeDetailData.lastViewedAt,
                    listVersion: episodeDetailData.medias ?? [],
                    listMarker: episodeDetailData.markers ?? []
                )
                
                
                self.updateFlagsAfterSelected()
            }
        } catch {
            print("error fetch detail:", error)
        }
    }
    
    func fetchWatchFromTheseLocation(guid: String, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        PlexAPI.shared.fetchWatchFromTheseLocation(guid: guid) { result in
            switch result {
            case .success(let metadatas):
                completion(metadatas)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchUserState(ratingKey: String, completion: @escaping (PlexUserState) -> Void = { _ in }) {
        PlexAPI.shared.fetchUserState(ratingKey: ratingKey) { result in
            switch result {
            case .success(let userState):
                completion(userState)
            case .failure(let error):
                print("Error from fetchUserState: \(error.localizedDescription)")
            }
        }
    }
    
    /// Chỉ guid dạng mới "plex://type/hash" mới lấy được ID hợp lệ cho API Discover. Guid dạng agent cũ
    /// (vd "com.plexapp.agents.themoviedb://12345?lang=en" — thường gặp ở thư viện scan bằng agent cũ,
    /// khác thư viện/server kia dùng agent Plex mới) sẽ ra 1 ID hoàn toàn khác ý nghĩa (ID TMDB, không
    /// phải ID Discover của Plex) — gọi Discover bằng ID đó luôn fail/sai dữ liệu. Trả nil để bỏ qua hẳn
    /// thay vì gọi 1 request chắc chắn fail hoặc load nhầm ảnh của phim khác.
    func extractRatingKey(from guid: String) -> String? {
        guard guid.hasPrefix("plex://") else { return nil }
        let base = guid.split(separator: "?").first ?? ""
        let components = base.split(separator: "/")
        return components.last.map(String.init)
    }
    
    func removeFromWatchlist(ratingKey: String) {
        PlexAPI.shared.removeFromWatchlist(ratingKey: ratingKey)
    }
    
    func addToWatchlist(ratingKey: String) {
        PlexAPI.shared.addToWatchlist(ratingKey: ratingKey)
    }
    
    func fetchRelatedByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping ([PlexHomeCollection]) -> Void = { _ in }) {
        PlexAPI.shared.fetchRelatedByRatingKey(ratingKey: ratingKey, isDiscover: isDiscover) { result in
            switch result {
            case .success(let collections):
                completion(collections)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchMetadatasByHubKey(key: String, offset: Int, size: Int, isDiscover: Bool, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        PlexAPI.shared.fetchMetadatasByHubKey(key: key, offset: offset, size: size, isDiscover: isDiscover) { result in
            switch result {
            case .success(let collections):
                completion(collections)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
    
    func groupEpisodesBySeason(episodes: [Episode]) -> [Season] {
        let grouped = Dictionary(grouping: episodes, by: { $0.seasonIndex })

        let seasons = grouped
            .sorted { $0.key < $1.key } // sort season asc
            .map { (seasonIndex, episodes) in
                Season(id: seasonIndex, name: "Mùa \(seasonIndex)", episodes: episodes, ratingKey: nil)
            }

        return seasons
    }
    
    func toggeWatchState(id: String, isMarkAsUnwatch: Bool) {
        PlexAPI.shared.toggleWatchState(id: id, isMarkAsUnwatch: isMarkAsUnwatch)
    }
    
    func updateFlagsAfterSelected() {
        self.selectedSubtitle = self.selectedMetadata?.listVersion.first?.parts.first?.streams.first {
            $0.streamType == 3 && $0.selected == true
        }
        
        self.selectedAudio = self.selectedMetadata?.listVersion.first?.parts.first?.streams.first {
            $0.streamType == 2 && $0.selected == true
        }
        self.isWatched = self.selectedMetadata?.lastViewedAt != nil && (self.selectedMetadata?.viewOffset == nil || self.selectedMetadata?.viewOffset == 0) ? true : false
    }
    
    deinit {
        print("🔴 Deinit MovieDetailViewModel")
    }
}
