//
//  PlexMediaPartStream.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//

struct PlexMediaPartStream: Identifiable, Codable {
    let id: Int
    let streamType: Int
    let title: String?
    let displayTitle: String
    let extendedDisplayTitle: String
    let codec: String
    let index: Int?
    let url: String?
    let selected: Bool?
    let languageTag: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case streamType
        case title
        case displayTitle
        case extendedDisplayTitle
        case codec
        case index
        case url = "key"
        case selected
        case languageTag
    }
    
    init(id: Int, streamType: Int, title: String, displayTitle: String, extendedDisplayTitle: String, codec: String, index: Int?, url: String, selected: Bool, languageTag: String) {
        self.id = id
        self.streamType = streamType
        self.title = title
        self.displayTitle = displayTitle
        self.extendedDisplayTitle = displayTitle
        self.codec = codec
        self.index = index
        self.url = url.isEmpty ? nil : url
        self.selected = selected
        self.languageTag = languageTag
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.streamType = try container.decode(Int.self, forKey: .streamType)
        self.title = try? container.decode(String.self, forKey: .title)
        self.displayTitle = try container.decode(String.self, forKey: .displayTitle)
        self.extendedDisplayTitle = try container.decode(String.self, forKey: .extendedDisplayTitle)
        self.codec = try container.decode(String.self, forKey: .codec)
        
        if let index = try? container.decode(Int.self, forKey: .index) {
            self.index = index
        } else {
            self.index = nil
        }
        
        if let url = try? container.decode(String.self, forKey: .url) {
            self.url = url
        } else {
            self.url = nil
        }
        
        if let selected = try? container.decode(Bool.self, forKey: .selected) {
            self.selected = selected
        } else {
            self.selected = nil
        }
        
        self.languageTag = try? container.decode(String.self, forKey: .languageTag)
    }
    
}
