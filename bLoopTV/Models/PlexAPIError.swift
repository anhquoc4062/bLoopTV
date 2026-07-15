//
//  PlexAPIError.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//
import Foundation

enum PlexAPIError: Error {
    case missingToken
    case invalidURL
    case serverError(String)
    case decodingError(Error)
    case encodingError(Error)
    case unknown(Error)
}
