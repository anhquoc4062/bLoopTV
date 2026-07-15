//
//  PlexSearchItemResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 11/6/25.
//

struct PlexSearchItemResponse: Codable {
    let mediaContainer: MediaContainer
    
    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
    
    struct MediaContainer: Codable {
        let searchResult: [PlexSearchItem]

        enum CodingKeys: String, CodingKey {
            case searchResult = "SearchResult"
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PlexSearchItemResponse.MediaContainer.CodingKeys> = try decoder.container(keyedBy: PlexSearchItemResponse.MediaContainer.CodingKeys.self)
            
            if let searchResult = try container.decodeIfPresent([PlexSearchItem].self, forKey: PlexSearchItemResponse.MediaContainer.CodingKeys.searchResult) {
                self.searchResult = searchResult
            } else {
                self.searchResult = []
            }
        }
    }
}
