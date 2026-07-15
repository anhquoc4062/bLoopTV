//
//  PlexUserStats.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//

import Foundation

struct PlexUserStats: Codable {
    let watchStats: WatchStats
    let ratingsStats: RatingsStats
    
    struct WatchStats: Codable {
        let movieAmount: String
        let movieSuffix: String
        let episodeAmount: String
        let episodeSuffix: String
        let showAmount: String
        let showSuffix: String
    }

    struct RatingsStats: Codable {
        let ratingsAmount: String
        let ratingsSuffix: String
    }
}
