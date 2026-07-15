//
//  PlexActorDetail.swift
//  VuaPhimBui
//
//  Created by Monster on 3/7/25.
//

class PlexActorDetail: Identifiable, Codable {
    let id: String
    let slug: String
    let title: String
    let summary: String
    let bornAt: String
    let birthPlace: String
    let thumb: String?
    let knownFor: String
    //    let image: [ImageInfo]
    //    let external: [ExternalLink]
    let creditType: [CreditType]
    
    //    struct ImageInfo: Codable {
    //        let alt: String
    //        let type: String
    //        let url: URL
    //    }
    //
    //    struct ExternalLink: Codable {
    //        let id: String
    //        let source: String
    //        let sourceTitle: String
    //        let url: URL
    //    }
    
    struct CreditType: Codable {
        let type: String
        let count: Int
        let title: String
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case slug
        case title
        case summary
        case bornAt
        case birthPlace
        case thumb
        case knownFor
//        case image = "Image"
//        case external = "External"
        case creditType = "CreditType"
    }
    
    init(
        id: String,
        slug: String,
        title: String,
        summary: String,
        bornAt: String,
        birthPlace: String,
        thumb: String?,
        knownFor: String,
        creditType: [CreditType],
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.summary = summary
        self.bornAt = bornAt
        self.birthPlace = birthPlace
        self.thumb = thumb
        self.knownFor = knownFor
        self.creditType = creditType
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.slug = try container.decode(String.self, forKey: .slug)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.bornAt = try container.decode(String.self, forKey: .bornAt)
        self.birthPlace = try container.decode(String.self, forKey: .birthPlace)
        self.thumb = try? container.decodeIfPresent(String.self, forKey: .thumb)
        self.knownFor = try container.decode(String.self, forKey: .knownFor)
//        self.image = try container.decode([ImageInfo].self, forKey: .image)
//        self.external = try container.decode([ExternalLink].self, forKey: .external)
        self.creditType = try container.decode([CreditType].self, forKey: .creditType)
    }
}
