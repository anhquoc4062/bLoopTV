//
//  SeasonViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 13/6/25.
//
import SwiftUI
import Combine


struct Episode: Identifiable {
    let id: String
    let title: String
    let grandTitle: String
    let thumbnailURL: URL?
    let episodeIndex: Int
    let seasonIndex: Int
    let summary: String
    let isWatched: Bool
    let viewOffset: Int
    let type: String
    let duration: Int
    let originallyAvailableAt: String?
    let medias: [PlexMedia]?
    
    var originallyAvailableAtDate: Date? {
        guard let raw = originallyAvailableAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: raw)
    }
}

//extension Episode: Hashable {
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
//    
//    static func == (lhs: Episode, rhs: Episode) -> Bool {
//        return lhs.id == rhs.id
//    }
//}

struct Season: Identifiable {
    let id: Int
    let name: String
    var episodes: [Episode]
    let ratingKey: String?
}

enum MediaChild {
    case season(Season)
    case episode(Episode)
}

class SeasonViewModel: ObservableObject {
    @Published var seasons: [Season] = []
    @Published var selectedSeasonID: Int?
    
    func groupEpisodesBySeason(episodes: [Episode]) -> [Season] {
        let grouped = Dictionary(grouping: episodes, by: { $0.seasonIndex })

        let seasons = grouped
            .sorted { $0.key < $1.key } // sort season asc
            .map { (seasonIndex, episodes) in
                Season(id: seasonIndex, name: "Mùa \(seasonIndex)", episodes: episodes, ratingKey: nil)
            }

        return seasons
    }
    
    func fetchAllLeaves(id: String, currentSeasonIndex: Int, completion: @escaping ([Episode]) -> Void = { _ in }) { // All episodes
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
                DispatchQueue.main.async {
                    self.seasons = self.groupEpisodesBySeason(episodes: episodes)
                }
                completion(episodes)
            case .failure(let error):
                print("Error from fetchAllLeaves: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchChildren(ratingKey: String, type: String, completion: @escaping ([MediaChild]) -> Void = { _ in }) {
        PlexAPI.shared.fetchChildren(ratingKey: ratingKey, isDiscover: true) { result in
            switch result {
            case .success(let metadatas):
                print("metadatas: \(metadatas)")
                if type == "season" {
                    let seasons = metadatas.map {
                        MediaChild.season(
                            Season(
                                id: $0.episodeIndex ?? 1,
                                name: "Mùa \($0.episodeIndex ?? 1)",
                                episodes: [],
                                ratingKey: $0.id
                            )
                        )
                    }
                    completion(seasons)
                } else if type == "episode" {
                    let episodes = metadatas.map {
                        MediaChild.episode(
                            Episode(
                                id: $0.id,
                                title: $0.title,
                                grandTitle: $0.grandparentTitle ?? "",
                                thumbnailURL: PlexAPI.shared.getPosterTranscodeURL(url: $0.poster, width: 900, height: 600),
                                episodeIndex: $0.episodeIndex ?? 1,
                                seasonIndex: $0.seasonIndex ?? 1,
                                summary: $0.summary,
                                isWatched: $0.lastViewedAt != nil && ($0.viewOffset == nil || $0.viewOffset == 0) ? true : false,
                                viewOffset: $0.viewOffset ?? 0,
                                type: $0.type,
                                duration: $0.duration,
                                originallyAvailableAt: $0.originallyAvailableAt,
                                medias: $0.medias ?? []
                            )
                        )
                    }
                    completion(episodes)
                }
            case .failure(let error):
                print("Error from fetchChildren type \(type): \(error.localizedDescription)")
            }
        }
    }
}
