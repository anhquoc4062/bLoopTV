//
//  PlexPinResponse.swift
//  Media App For Plex
//
//  Created by Monster on 23/5/25.
//

import Foundation

struct PlexPinResponse: Decodable {
    let id: Int
    let code: String
    let authToken: String?
}
