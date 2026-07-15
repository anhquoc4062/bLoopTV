//
//  PlexTogetherAPI.swift
//  VuaPhimBui
//
//  Created by Monster on 20/7/25.
//
import Foundation

struct CreateRoomPayload: Codable {
    let sourceUri: String
    let title: String
    let users: [Int]
}

struct EmptyBody: Encodable {}

class PlexTogetherAPI {
    
    static let shared = PlexTogetherAPI()
    
    private var plexToken: String? {
        UserDefaults.standard.string(forKey: "plexToken")
    }
    
    private var plexClientIdentifier: String {
        UserDefaults.standard.string(forKey: "plexClientIdentifier") ?? ""
    }
    
    // MARK: - Request method
    func request<T: Decodable, B: Encodable>(
        method: String = "GET",
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: B? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, PlexAPIError>) -> Void
    ) {
        guard let token = plexToken else {
            completion(.failure(.missingToken))
            return
        }

        // Construct URL
        var components = URLComponents(string: Environment.togetherBaseURL + path)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode body if present
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                completion(.failure(.encodingError(error)))
                return
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.unknown(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.serverError("No data returned")))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(responseType, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
    
    func fetchRooms(completion: @escaping (Result<[PlexWatchTogetherRoom], Error>) -> Void) {
        let path = "/rooms"
        let queryItems = [
            URLQueryItem(name: "type", value: String(1)),
        ]
        
        request(method: "GET", path: path, queryItems: queryItems, body: nil as EmptyBody?, responseType: PlexWatchTogetherResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.rooms))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func createRoom(
        sourceUri: String,
        title: String,
        userIDs: [Int],
        completion: @escaping (Result<PlexWatchTogetherRoom, Error>) -> Void
    ) {
        let path = "/rooms"
        let queryItems = [URLQueryItem(name: "type", value: "1")]
        
        let payload = CreateRoomPayload(sourceUri: sourceUri, title: title, users: userIDs)
        
        request(
            method: "POST",
            path: path,
            queryItems: queryItems,
            body: payload,
            responseType: PlexWatchTogetherRoom.self
        ) { result in
            switch result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                print("❌ Failed to create room:", error)
                completion(.failure(error))
            }
        }
    }
    
    func deleteRoom(id: String, completion: @escaping (Result<Void, PlexAPIError>) -> Void) {
        guard let token = plexToken else {
            completion(.failure(.missingToken))
            return
        }

        let urlString = Environment.togetherBaseURL + "/rooms/\(id)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.unknown(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.serverError("Invalid response")))
                return
            }

            if (200..<300).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(.serverError("Status code: \(httpResponse.statusCode)")))
            }
        }.resume()
    }

}
