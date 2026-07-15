//
//  PlexEnvironment.swift
//  Media App For Plex
//
//  Created by Monster on 23/5/25.
//

import Foundation

enum Environment {
    static var baseURL: String {
        Bundle.main.infoDictionary?["PLEX_BASE_URL"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_BASE_URL"]
        ?? "https://plex.tv/api"
    }
    
    static var discoverBaseURL: String {
        Bundle.main.infoDictionary?["PLEX_DISCOVER_BASE_URL"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_DISCOVER_BASE_URL"]
        ?? "https://discover.provider.plex.tv"
    }
    
    static var clientBaseURL: String {
        Bundle.main.infoDictionary?["PLEX_CLIENT_BASE_URL"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_CLIENT_BASE_URL"]
        ?? "https://clients.plex.tv/api/v2"
    }
    
    static var communityBaseURL: String {
        Bundle.main.infoDictionary?["PLEX_COMMUNITY_BASE_URL"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_COMMUNITY_BASE_URL"]
        ?? "https://community.plex.tv"
    }
    
    static var togetherBaseURL: String {
        Bundle.main.infoDictionary?["PLEX_COMMUNITY_BASE_URL"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_TOGETHER_BASE_URL"]
        ?? "https://together.plex.tv"
    }

    static var clientIdentifier: String {
        Bundle.main.infoDictionary?["PLEX_CLIENT_IDENTIFIER"] as? String
        ?? ProcessInfo.processInfo.environment["PLEX_CLIENT_IDENTIFIER"]
        ?? "bloop-app-client"
    }
}
