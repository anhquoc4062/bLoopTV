//
//  PlexAllFriendsResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 5/7/25.
//
import Foundation

struct PlexAllFriendsResponse: Decodable {
    let data: PlexAllFriendsData
    
    struct PlexAllFriendsData: Decodable {
        let allFriendsV2: [PlexFriendWrapper]
        
        struct PlexFriendWrapper: Decodable {
            let user: PlexFriendUser
        }
    }
}
