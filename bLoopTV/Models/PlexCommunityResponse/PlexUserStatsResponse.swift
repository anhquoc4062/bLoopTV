//
//  PlexUserStatsResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//
import Foundation

struct PlexUserStatsResponse: Decodable {
    let data: PlexUserDetailWrapper
    
    struct PlexUserDetailWrapper: Decodable {
        let userByUsername: PlexUserStats
    }
}

