//
//  PlexWatchHistoryResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//

struct PlexWatchHistoryResponse: Codable {
    let data: UserDataContainer
    
    struct UserDataContainer: Codable {
        let user: PlexUser
        
        struct PlexUser: Codable {
            let watchHistory: WatchHistory
        }

        struct WatchHistory: Codable {
            let nodes: [WatchHistoryNode]
        }

        struct WatchHistoryNode: Codable {
            let metadataItem: PlexMetaData
            let date: String
            let id: String
            
            enum CodingKeys: String, CodingKey {
               case id
               case date
               case metadataItem
           }
            
            init(
                id: String,
                date: String,
                metadataItem: PlexMetaData,
            ) {
                self.id = id
                self.date = date
                self.metadataItem = metadataItem
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.id = try container.decode(String.self, forKey: .id)
                self.date = try container.decode(String.self, forKey: .date)
                
                var item = try container.decode(PlexMetaData.self, forKey: .metadataItem)
                item.watchId = try container.decode(String.self, forKey: .id)

                self.metadataItem = item
            }
        }
    }

    
}


