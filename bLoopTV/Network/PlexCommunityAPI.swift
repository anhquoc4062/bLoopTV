//
//  PlexCommunityAPI.swift
//  VuaPhimBui
//
//  Created by Monster on 5/7/25.
//

import Foundation

class PlexCommunityAPI {
    static let shared = PlexCommunityAPI()
    
    private var plexServerToken: String? {
        UserDefaults.standard.string(forKey: "plexServerToken")
    }
    
    private var plexToken: String? {
        UserDefaults.standard.string(forKey: "plexToken")
    }
    
    private var plexBaseUrl: String {
        UserDefaults.standard.string(forKey: "plexBaseUrl") ?? ""
    }
    
    func request(
        query: String,
        operationName: String,
        variables: [String: Any]? = nil,
        headers: [String: String] = [:],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard let token = plexToken else {
            completion(.failure(NSError(domain: "Invalid token", code: -1)))
            return
        }
        let url = URL(string: "\(Environment.communityBaseURL)/api")!
        var body: [String: Any] = [
            "query": query,
            "operationName": operationName
        ]
        
        if let variables = variables {
            body["variables"] = variables
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(NSError(domain: "Invalid JSON body", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = jsonData
        
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("body:\n\(jsonString)")
        }
        
//        print("request: \(request)")
//        print("jsonData: \(jsonData)")
//        print("plexToken: \(token)")
//        print("query: \(query)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -2)))
                return
            }

            completion(.success(data))
        }.resume()
    }
    
    func fetchAllFriends(completion: @escaping (Result<[PlexFriendUser], Error>) -> Void) {
        let query = "\n    query GetAllFriends {\n  allFriendsV2 {\n    user {\n      avatar\n      displayName\n      id\n      username\n      idRaw\n    }\n    createdAt\n  }\n}\n    "

        request(query: query, operationName: "GetAllFriends") { result in
            switch result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(PlexAllFriendsResponse.self, from: data)
                    let users: [PlexFriendUser] = decoded.data.allFriendsV2.map { $0.user }
                    completion(.success(users))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendMessage(
        message: String,
        recipients: [String],
        guid: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let query = """
        mutation sendMessage($input: CreateMessageInput!) {
          createMessage(input: $input) {
            __typename
          }
        }
        """

        let variables: [String: Any] = [
            "input": [
                "message": message,
                "recipients": recipients,
                "item": guid,
                "type": "METADATA_MESSAGE"
            ]
        ]

        request(query: query, operationName: "sendMessage", variables: variables) { result in
            switch result {
            case .success(let data):
//                if let response = String(data: data, encoding: .utf8) {
//                    print("Message response:\n\(response)")
//                }
                completion(.success(()))
            case .failure(let error):
                print("Failed to send message:", error)
                completion(.failure(error))
            }
        }
    }
    
    func fetchWatchHistory(
        uuid: String,
        completion: @escaping (Result<[PlexMetaData], Error>) -> Void
    ) {
        let query = "\n    query GetWatchHistoryHub($uuid: ID = \"\", $first: PaginationInt!, $after: String, $skipUserState: Boolean = false) {\n  user(id: $uuid) {\n    watchHistory(first: $first, after: $after) {\n      nodes {\n        metadataItem {\n          ...itemFields\n        }\n        date\n        id\n      }\n      pageInfo {\n        hasNextPage\n        hasPreviousPage\n        endCursor\n      }\n    }\n  }\n}\n    \n    fragment itemFields on MetadataItem {\n  id\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n  title\n  key\n  type\n  index\n  publicPagesURL\n  parent {\n    ...parentFields\n  }\n  grandparent {\n    ...parentFields\n  }\n  publishedAt\n  leafCount\n  year\n  originallyAvailableAt\n  childCount\n}\n    \n\n    fragment parentFields on MetadataItem {\n  index\n  title\n  publishedAt\n  key\n  type\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n}\n    "

        let variables: [String: Any] = [
            "first": 50,
            "skipUserState": true,
            "uuid": uuid
        ]
        
        request(query: query, operationName: "GetWatchHistoryHub", variables: variables) { result in
            switch result {
            case .success(let data):
//                if let response = String(data: data, encoding: .utf8) {
//                    print("Message response uuid \(uuid):\n\(response)")
//                }
                do {
                    let decoded = try JSONDecoder().decode(PlexWatchHistoryResponse.self, from: data)
                    let metadatas: [PlexMetaData] = decoded.data.user.watchHistory.nodes.map { $0.metadataItem }
                    // print("metadatas: \(metadatas)")
                    completion(.success(metadatas))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchReviews(
        uuid: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let query = "\n    query GetReviewsHub($uuid: ID = \"\", $first: PaginationInt!, $after: String, $skipUserState: Boolean = false) {\n  user(id: $uuid) {\n    reviews(first: $first, after: $after) {\n      nodes {\n        ... on ActivityRating {\n          ...ActivityRatingFragment\n        }\n        ... on ActivityWatchRating {\n          ...ActivityWatchRatingFragment\n        }\n        ... on ActivityReview {\n          ...ActivityReviewFragment\n        }\n        ... on ActivityWatchReview {\n          ...ActivityWatchReviewFragment\n        }\n      }\n      pageInfo {\n        hasNextPage\n        hasPreviousPage\n        endCursor\n      }\n    }\n  }\n}\n    \n    fragment ActivityRatingFragment on ActivityRating {\n  ...activityFragment\n  rating\n}\n    \n\n    fragment activityFragment on Activity {\n  __typename\n  commentCount\n  date\n  id\n  isMuted\n  isPrimary\n  privacy\n  reaction\n  reactionsCount\n  reactionsTypes\n  metadataItem {\n    ...itemFields\n  }\n  userV2 {\n    id\n    username\n    displayName\n    avatar\n    friendStatus\n    isMuted\n    isHidden\n    isBlocked\n    mutualFriends {\n      count\n      friends {\n        avatar\n        displayName\n        id\n        username\n      }\n    }\n  }\n}\n    \n\n    fragment itemFields on MetadataItem {\n  id\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n  title\n  key\n  type\n  index\n  publicPagesURL\n  parent {\n    ...parentFields\n  }\n  grandparent {\n    ...parentFields\n  }\n  publishedAt\n  leafCount\n  year\n  originallyAvailableAt\n  childCount\n}\n    \n\n    fragment parentFields on MetadataItem {\n  index\n  title\n  publishedAt\n  key\n  type\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n}\n    \n\n    fragment ActivityWatchRatingFragment on ActivityWatchRating {\n  ...activityFragment\n  rating\n}\n    \n\n    fragment ActivityReviewFragment on ActivityReview {\n  ...activityFragment\n  reviewRating: rating\n  hasSpoilers\n  message\n  updatedAt\n  status\n  updatedAt\n}\n    \n\n    fragment ActivityWatchReviewFragment on ActivityWatchReview {\n  ...activityFragment\n  reviewRating: rating\n  hasSpoilers\n  message\n  updatedAt\n  status\n  updatedAt\n}\n    "


        let variables: [String: Any] = [
            "first": 50,
            "skipUserState": true,
            "uuid": uuid
        ]

        request(query: query, operationName: "GetReviewsHub", variables: variables) { result in
            switch result {
            case .success(let data):
//                if let response = String(data: data, encoding: .utf8) {
//                    print("Message response:\n\(response)")
//                }
                completion(.success(()))
            case .failure(let error):
                print("Failed to send message:", error)
                completion(.failure(error))
            }
        }
    }
    
    func fetchWatchlistHub(
        uuid: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let query = "\n    query GetWatchlistHub($uuid: ID = \"\", $first: PaginationInt!, $after: String, $skipUserState: Boolean = false) {\n  user(id: $uuid) {\n    watchlist(first: $first, after: $after) {\n      nodes {\n        ...itemFields\n      }\n      pageInfo {\n        hasNextPage\n        hasPreviousPage\n        endCursor\n      }\n    }\n  }\n}\n    \n    fragment itemFields on MetadataItem {\n  id\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n  title\n  key\n  type\n  index\n  publicPagesURL\n  parent {\n    ...parentFields\n  }\n  grandparent {\n    ...parentFields\n  }\n  publishedAt\n  leafCount\n  year\n  originallyAvailableAt\n  childCount\n}\n    \n\n    fragment parentFields on MetadataItem {\n  index\n  title\n  publishedAt\n  key\n  type\n  images {\n    coverArt\n    coverPoster\n    thumbnail\n    art\n  }\n  userState @skip(if: $skipUserState) {\n    viewCount\n    viewedLeafCount\n    watchlistedAt\n  }\n}\n    "


        let variables: [String: Any] = [
            "first": 50,
            "skipUserState": true,
            "uuid": uuid
        ]

        request(query: query, operationName: "GetWatchlistHub", variables: variables) { result in
            switch result {
            case .success(let data):
//                if let response = String(data: data, encoding: .utf8) {
//                    print("Message response:\n\(response)")
//                }
                completion(.success(()))
            case .failure(let error):
                print("Failed to send message:", error)
                completion(.failure(error))
            }
        }
    }
    
    func fetchUserDetail(
        username: String,
        completion: @escaping (Result<PlexUserDetailData, Error>) -> Void
    ) {
        let query = "\n    query GetUserDetails($username: ID!) {\n  userByUsername(username: $username) {\n    id\n    avatar\n    username\n    displayName\n    bio\n    createdAt\n    friendStatus\n    isBlocked\n    isMuted\n    location\n    plexPass\n    url\n    mutualFriends {\n      count\n      friends {\n        avatar\n        displayName\n        id\n        username\n      }\n    }\n  }\n}\n    "


        let variables: [String: Any] = [
            "username": username
        ]

        request(query: query, operationName: "GetUserDetails", variables: variables) { result in
            switch result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(PlexUserDetailDataResponse.self, from: data)
                    let userDetailData: PlexUserDetailData = decoded.data.userByUsername
                    // print("userDetailData: \(userDetailData)")
                    completion(.success(userDetailData))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchUserStats(
        username: String,
        completion: @escaping (Result<PlexUserStats, Error>) -> Void
    ) {
        let query = "\n    query GetUserStats($username: ID!) {\n  userByUsername(username: $username) {\n    watchStats {\n      movieAmount\n      movieSuffix\n      episodeAmount\n      episodeSuffix\n      showAmount\n      showSuffix\n    }\n    ratingsStats {\n      ratingsAmount\n      ratingsSuffix\n    }\n  }\n}\n    "

        let variables: [String: Any] = [
            "username": username
        ]

        request(query: query, operationName: "GetUserStats", variables: variables) { result in
            switch result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(PlexUserStatsResponse.self, from: data)
                    let userStatsData: PlexUserStats = decoded.data.userByUsername
                    // print("userStatsData: \(userStatsData)")
                    completion(.success(userStatsData))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    
}
