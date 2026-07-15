//
//  UserAPI.swift
//  VuaPhimBui
//
//  Created by Monster on 27/6/25.
//

import Foundation

class UserAPI {
    static let shared = UserAPI()
    
    private var plexToken: String? {
        UserDefaults.standard.string(forKey: "plexToken")
    }
    func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        responseType: T.Type,
        isCommunityURL: Bool = false,
        completion: @escaping (Result<T, PlexAPIError>) -> Void,
    ) {
        guard let token = plexToken else {
            completion(.failure(.missingToken))
            return
        }
        
        // Construct URL
        var components = URLComponents(string: (isCommunityURL ? Environment.communityBaseURL : Environment.clientBaseURL) + path)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(Environment.clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("request: \(request)")
        
        // Make request
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
    
    func fetchUserInformation(completion: @escaping (Result<PlexUserData, Error>) -> Void) {
        let path = "/user"
        let queryItems = [
            URLQueryItem(name: "X-Plex-Device-Name", value: "iOS"),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexUserData.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
}
