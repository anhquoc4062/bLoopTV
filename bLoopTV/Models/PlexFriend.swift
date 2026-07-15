//
//  PlexFriend.swift
//  VuaPhimBui
//
//  Created by Monster on 5/7/25.
//
import Foundation

struct PlexFriendUser: Identifiable, Decodable {
    let id: String
    let avatar: String
    let displayName: String
    let username: String
    let idRaw: Int
}
