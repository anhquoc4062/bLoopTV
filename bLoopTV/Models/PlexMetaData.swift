//
//  PlexMetaData.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//
import Foundation

struct PlexMetaData: Identifiable, Codable, Hashable {
    let id: String
    let ratingKey: String?
    let parentId: String?
    let grandParentId: String?
    let title: String
    let grandParentTitle: String?
    let type: String
    let poster: String?
    let thumbnail: String?
    let year: String?
    let seasonIndex: Int?
    let episodeIndex: Int?
    let addedAt: Int?
    let updatedAt: Int?
    let ultraBlurColors: PlexUltraBlurColors?
    let genres: [PlexGenre]?
    let contentRating: String?
    let duration: Int?
    let librarySectionTitle: String?
    let images: [PlexImage]?
    let guid: String?
    let audienceRating: Float?
    let childCount: Int?
    let leafCount: Int?
    let summary: String
    let imageSources: ImageSources?
    var watchId: String?
    let tagline: String?
    let viewOffset: Int?
    let lastViewedAt: Int?
    
    struct ImageSources: Codable, Hashable {
       let coverPoster: String?
       let coverArt: String?
       let thumbnail: String?
       let art: String?
   }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ratingKey
        case parentId = "parentRatingKey"
        case grandParentId = "grandparentRatingKey"
        case title = "title"
        case grandParentTitle = "grandparentTitle"
        case type = "type"
        case poster = "thumb"
        case thumbnail = "art"
        case year = "year"
        case seasonIndex = "parentIndex"
        case episodeIndex = "index"
        case addedAt
        case updatedAt
        case ultraBlurColors = "UltraBlurColors"
        case genres = "Genre"
        case contentRating
        case duration
        case librarySectionTitle
        case images = "Image"
        case guid = "guid"
        case audienceRating = "audienceRating"
        case childCount
        case leafCount
        case summary
        case imageSources = "images"
        case tagline = "tagline"
        case viewOffset = "viewOffset"
        case lastViewedAt = "lastViewedAt"
    }
    
    init(
        id: String,
        ratingKey: String,
        uuid: UUID,
        parentId: String,
        grandParentId: String,
        title: String,
        grandParentTitle: String,
        type: String,
        poster: String,
        thumbnail: String,
        year: String?,
        seasonIndex: Int?,
        episodeIndex: Int?,
        addedAt: Int,
        updatedAt: Int,
        ultraBlurColors: PlexUltraBlurColors,
        genres: [PlexGenre],
        contentRating: String,
        duration: Int,
        librarySectionTitle: String,
        images: [PlexImage],
        guid: String,
        audienceRating: Float,
        childCount: Int,
        leafCount: Int,
        summary: String,
        imageSources: ImageSources,
        tagline: String,
        viewOffset: Int,
        lastViewedAt: Int,
    ) {
        self.id = id
        self.ratingKey = ratingKey
        self.parentId = parentId
        self.grandParentId = grandParentId
        self.title = title
        self.grandParentTitle = grandParentTitle
        self.type = type
        self.poster = poster
        self.thumbnail = thumbnail
        self.year = year
        self.seasonIndex = seasonIndex
        self.episodeIndex = episodeIndex
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.ultraBlurColors = ultraBlurColors
        self.genres = genres
        self.contentRating = contentRating
        self.duration = duration
        self.librarySectionTitle = librarySectionTitle
        self.images = images
        self.guid = guid
        self.audienceRating = audienceRating
        self.childCount = childCount
        self.leafCount = leafCount
        self.summary = summary
        self.imageSources = imageSources
        self.tagline = tagline
        self.viewOffset = viewOffset
        self.lastViewedAt = lastViewedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .ratingKey)
                    ?? container.decode(String.self, forKey: .id)
        self.parentId = try? container.decode(String.self, forKey: .parentId)
        self.ratingKey = try? container.decode(String.self, forKey: .ratingKey)
        self.grandParentId = try? container.decode(String.self, forKey: .grandParentId)
        
        self.title = try container.decode(String.self, forKey: .title)
        
        if let grandParentTitle = try? container.decode(String.self, forKey: .grandParentTitle) {
            self.grandParentTitle = grandParentTitle
        } else {
            self.grandParentTitle = nil
        }
        
        self.type = try container.decode(String.self, forKey: .type)
        
        let decodedImageSources = try? container.decode(ImageSources.self, forKey: .imageSources)
        self.imageSources = decodedImageSources

        self.poster = (try? container.decode(String.self, forKey: .poster))
            ?? decodedImageSources?.coverPoster

        self.thumbnail = (try? container.decode(String.self, forKey: .thumbnail))
            ?? decodedImageSources?.thumbnail
        
        if let year = try? container.decode(Int.self, forKey: .year) {
            self.year = String(year)
        } else {
            if let year = try? container.decode(String.self, forKey: .year) {
                self.year = year
            } else {
                self.year = nil
                
            }
        }
        
        if let seasonIndex = try? container.decode(Int.self, forKey: .seasonIndex) {
            self.seasonIndex = seasonIndex
        } else {
            self.seasonIndex = nil
            
        }
        
        if let episodeIndex = try? container.decode(Int.self, forKey: .episodeIndex) {
            self.episodeIndex = episodeIndex
        } else {
            self.episodeIndex = nil
            
        }
        self.addedAt = try? container.decode(Int.self, forKey: .addedAt)
        self.updatedAt = try? container.decode(Int.self, forKey: .updatedAt)
        
        if let ultraBlurColors = try? container.decode(PlexUltraBlurColors.self, forKey: .ultraBlurColors) {
            self.ultraBlurColors = ultraBlurColors
        } else {
            self.ultraBlurColors = nil
            
        }
        
        if let genres = try? container.decode([PlexGenre].self, forKey: .genres) {
            self.genres = genres
        } else {
            self.genres = nil
            
        }
        
        if let contentRating = try? container.decode(String.self, forKey: .contentRating) {
            self.contentRating = contentRating
        } else {
            self.contentRating = nil
            
        }
        
        if let duration = try? container.decode(Int.self, forKey: .duration) {
            self.duration = duration
        } else {
            self.duration = nil
            
        }
        
        self.librarySectionTitle = try? container.decode(String.self, forKey: .librarySectionTitle)
        self.images = try? container.decode([PlexImage].self, forKey: .images)
        self.guid = try? container.decode(String.self, forKey: .guid)
        self.audienceRating = try? container.decode(Float.self, forKey: .audienceRating)
        self.childCount = try? container.decode(Int.self, forKey: .childCount)
        self.leafCount = try? container.decode(Int.self, forKey: .leafCount)
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.tagline = (try? container.decode(String.self, forKey: .tagline)) ?? ""
        self.viewOffset = (try? container.decode(Int.self, forKey: .viewOffset)) ?? 0
        self.lastViewedAt = (try? container.decode(Int.self, forKey: .lastViewedAt)) ?? 0
    }
    
}
