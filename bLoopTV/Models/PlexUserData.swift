//
//  PlexUserData.swift
//  VuaPhimBui
//
//  Created by Monster on 27/6/25.
//

import Foundation

struct PlexUserData: Identifiable, Codable, Hashable {
    let id: String
    let userId: Int
    let avatar: String
    let username: String?
    let friendlyName: String?
    let title: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case userId = "id"
        case avatar = "thumb"
        case username
        case friendlyName
        case title
        case email
    }
}
