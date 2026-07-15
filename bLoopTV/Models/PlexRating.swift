//
//  PlexRating.swift
//  VuaPhimBui
//
//  Created by Monster on 29/6/25.
//

import Foundation

struct PlexRating: Identifiable, Codable, Hashable {
    let image: String
    let type: String
    let value: Double
    
    var id: String { "\(image)-\(type)" }
    
    var mappedImageName: String {
        switch image {
        case "imdb://image.rating":
            return "IMDbIcon"
        case "rottentomatoes://image.rating.ripe":
            return "TomatoesHigh"
        case "rottentomatoes://image.rating.rotten":
            return "TomatoesLow"
        case "rottentomatoes://image.rating.upright":
            return "PopcornHigh"
        case "rottentomatoes://image.rating.spilled":
            return "PopcornLow"
        case "themoviedb://image.rating":
            return "TMDbIcon"
        default:
            return "DefaultIcon"
        }
    }
    
    var normalizedValue: String {
        if image.contains("imdb") {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f%%", value * 10)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case image
        case type
        case value
    }
}
