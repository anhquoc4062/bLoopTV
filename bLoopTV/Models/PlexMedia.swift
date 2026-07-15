//
//  PlexMedia.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//

struct PlexMedia: Identifiable, Codable {
    let id: Int
    let videoResolution: String
    let bitrate: Int?
    let parts: [PlexMediaPart]
    let videoCodec: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoResolution
        case bitrate
        case parts = "Part"
        case videoCodec
    }
    
    init(
        id: Int,
        videoResolution: String,
        bitrate: Int,
        parts: [PlexMediaPart],
        videoCodec: String,
    ) {
        self.id = id
        self.videoResolution = videoResolution
        self.bitrate = bitrate
        self.parts = parts
        self.videoCodec = videoCodec
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.videoResolution = try container.decode(String.self, forKey: .videoResolution)
        self.bitrate = try? container.decode(Int.self, forKey: .bitrate)
        self.parts = try container.decode([PlexMediaPart].self, forKey: .parts)
        self.videoCodec = try container.decode(String.self, forKey: .videoCodec)
        
    }
}
