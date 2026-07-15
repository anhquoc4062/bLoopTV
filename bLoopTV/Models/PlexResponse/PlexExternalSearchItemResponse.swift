//
//  PlexExternalSearchItemResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 23/6/25.
//

struct PlexExternalSearchItemResponse: Codable {
    let mediaContainer: MediaContainer
    
    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
    
    struct MediaContainer: Codable {
        let searchResults: [PlexSearchResults]
        let suggestedTerms: [String]

        enum CodingKeys: String, CodingKey {
            case searchResults = "SearchResults"
            case suggestedTerms
        }
        
        struct PlexSearchResults: Codable {
            let id: String
            let searchResult: [PlexSearchItem]?
            
            enum CodingKeys: String, CodingKey {
                case id
                case searchResult = "SearchResult"
            }
        }
    }
}
