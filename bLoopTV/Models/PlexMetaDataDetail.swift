//
//  PlexMetaDataDetail.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//

class PlexMetaDataDetail: Codable {
    let id: String
    let summary: String
    let genres: [PlexGenre]?
    let medias: [PlexMedia]?
    let onDeck: PlexOnDeck?
    let viewOffset: Int?
    let roles: [PlexActor]?
    let directors: [PlexActor]?
    let episodeIndex: Int?
    let seasonIndex: Int?
    let duration: Int
    let type: String
    let lastViewedAt: Int?
    let title: String
    let poster: String?
    let parentTitle: String?
    let grandparentTitle: String?
    let guid: String?
    let images: [PlexImage]?
    let ultraBlurColors: PlexUltraBlurColors?
    let rating: [PlexRating]?
    let extras: PlexExtra?
    let markers: [PlexMarker]?
    let key: String?
    let originallyAvailableAt: String?
    let themeSong: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case summary
        case genres = "Genre"
        case medias = "Media"
        case onDeck = "OnDeck"
        case viewOffset
        case roles = "Role"
        case directors = "Director"
        case episodeIndex = "index"
        case seasonIndex = "parentIndex"
        case duration
        case type
        case lastViewedAt
        case title
        case poster = "thumb"
        case parentTitle
        case grandparentTitle
        case guid
        case images = "Image"
        case ultraBlurColors = "UltraBlurColors"
        case rating = "Rating"
        case extras = "Extras"
        case markers = "Marker"
        case key
        case originallyAvailableAt
        case themeSong = "theme"
    }
    
    init(
        id: String,
        summary: String,
        genres: [PlexGenre],
        medias: [PlexMedia],
        onDeck: PlexOnDeck,
        viewOffset: Int,
        roles: [PlexActor],
        directors: [PlexActor],
        episodeIndex: Int?,
        seasonIndex: Int?,
        duration: Int,
        type: String,
        lastViewedAt: Int,
        title: String,
        poster: String,
        parentTitle: String,
        grandparentTitle: String,
        guid: String,
        images: [PlexImage],
        ultraBlurColors: PlexUltraBlurColors,
        rating: [PlexRating],
        extras: PlexExtra,
        markers: [PlexMarker],
        key: String,
        originallyAvailableAt: String,
        themeSong: String,
    ) {
        self.id = id
        self.summary = summary
        self.genres = genres
        self.medias = medias
        self.onDeck = onDeck
        self.viewOffset = viewOffset
        self.roles = roles
        self.directors = directors
        self.episodeIndex = episodeIndex
        self.seasonIndex = seasonIndex
        self.duration = duration
        self.type = type
        self.lastViewedAt = lastViewedAt
        self.title = title
        self.poster = poster
        self.parentTitle = parentTitle
        self.grandparentTitle = grandparentTitle
        self.guid = guid
        self.images = images
        self.ultraBlurColors = ultraBlurColors
        self.rating = rating
        self.extras = extras
        self.markers = markers
        self.key = key
        self.originallyAvailableAt = originallyAvailableAt
        self.themeSong = themeSong
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""

        if let genres = try? container.decode([PlexGenre].self, forKey: .genres) {
            self.genres = genres
        } else {
            self.genres = nil
        }
        
        self.medias = try? container.decode([PlexMedia].self, forKey: .medias)
        
        if let onDeck = try? container.decode(PlexOnDeck.self, forKey: .onDeck) {
            self.onDeck = onDeck
        } else {
            self.onDeck = nil
        }
        
        // self.onDeck = try container.decode(PlexOnDeck.self, forKey: .onDeck)
        
        if let viewOffset = try? container.decode(Int.self, forKey: .viewOffset) {
            self.viewOffset = viewOffset
        } else {
            self.viewOffset = nil
        }
        
        self.roles = try? container.decode([PlexActor].self, forKey: .roles)
        self.directors = try? container.decode([PlexActor].self, forKey: .directors)
        self.episodeIndex = try? container.decode(Int.self, forKey: .episodeIndex)
        self.seasonIndex = try? container.decode(Int.self, forKey: .seasonIndex)
        
        if let duration = try? container.decode(Int.self, forKey: .duration) {
            self.duration = duration
        } else {
            self.duration = 0
        }
        self.type = try container.decode(String.self, forKey: .type)
        self.lastViewedAt = try? container.decode(Int.self, forKey: .lastViewedAt)
        self.title = try container.decode(String.self, forKey: .title)
        self.poster = try? container.decode(String.self, forKey: .poster)
        self.parentTitle = try? container.decode(String.self, forKey: .parentTitle)
        self.grandparentTitle = try? container.decode(String.self, forKey: .grandparentTitle)
        self.guid = try? container.decode(String.self, forKey: .guid)
        self.images = try? container.decode([PlexImage].self, forKey: .images)
        self.ultraBlurColors = try? container.decode(PlexUltraBlurColors.self, forKey: .ultraBlurColors)
        self.rating = try? container.decode([PlexRating].self, forKey: .rating)
        self.extras = try? container.decode(PlexExtra.self, forKey: .extras)
        self.markers = try? container.decode([PlexMarker].self, forKey: .markers)
        self.key = try? container.decode(String.self, forKey: .key)
        self.originallyAvailableAt = try? container.decode(String.self, forKey: .originallyAvailableAt)
        self.themeSong = try? container.decode(String.self, forKey: .themeSong)
    }
}
