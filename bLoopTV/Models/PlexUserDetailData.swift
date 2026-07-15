//
//  PlexUserDetailData.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//

import Foundation

struct PlexUserDetailData: Identifiable, Codable, Hashable {
    let id: String
    let avatar: String?
    let username: String
    let displayName: String?
    let bio: String?
    let createdAt: String?
    let plexPass: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case avatar
        case username
        case displayName
        case bio
        case createdAt
        case plexPass
    }
}
