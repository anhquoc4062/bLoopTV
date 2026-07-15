//
//  PlexResourcesResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 30/5/25.
//
import Network

struct PlexResourcesResponse: Decodable {
    let devices: [PlexDevice]

    enum CodingKeys: String, CodingKey {
        case devices = "Device"
    }
}

struct PlexDevice: Decodable {
    let name: String
    let accessToken: String?
    let provides: String
    let presence: Bool
    let connections: [PlexConnection]
    let ownerId: Int?
    let serverDeviceIdentifier: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case accessToken
        case provides
        case presence
        case connections
        case ownerId
        case serverDeviceIdentifier = "clientIdentifier"
    }
}

struct PlexConnection: Decodable {
    enum AddressType {
        case ipv4, ipv6, domain
    }
    
    let uri: String
    let address: String
    let local: Bool
    let ipv6: Bool
    let addressType: AddressType
    
    enum CodingKeys: String, CodingKey {
        case uri
        case address
        case local
        case ipv6 = "IPv6"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uri = try container.decode(String.self, forKey: .uri)
        address = try container.decode(String.self, forKey: .address)
        local = try container.decode(Bool.self, forKey: .local)
        ipv6 = try container.decode(Bool.self, forKey: .ipv6)
        
        if ipv6 {
            addressType = .ipv6
        } else if IPv4Address(address) != nil {
            addressType = .ipv4
        } else {
            addressType = .domain
        }
    }
}
