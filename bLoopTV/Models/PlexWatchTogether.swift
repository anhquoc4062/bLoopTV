//
//  PlexWatchTogether.swift
//  VuaPhimBui
//
//  Created by Monster on 20/7/25.
//
import Foundation

struct PlexWatchTogetherRoom: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let type: String
    let source: String
    let sourceUri: String
    let syncplayHost: String
    let syncplayPort: Int
    
    let users: [PlexUserData]?
    
    var ratingKey: String? {
        guard let range = sourceUri.range(of: "/library/metadata/") else {
            return nil
        }
        let substring = sourceUri[range.upperBound...]
        let key = substring.split(separator: "/").first
        return key.map(String.init)
    }

    var thumb: String? {
        guard let ratingKey = ratingKey else { return nil }
        return "/library/metadata/\(ratingKey)/art"
    }
}
