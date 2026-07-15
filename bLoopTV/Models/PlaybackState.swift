//
//  PlaybackState.swift
//  VuaPhimBui
//
//  Created by Monster on 21/7/25.
//

struct PlayStatePayload {
    let paused: Bool
    let doSeek: Bool
    let setBy: String?
    let position: Double
    let userID: String?
    let deviceIdentifier: String?
    let ignoreClient: Int
    let ignoreServer: Int
}

