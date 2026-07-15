//
//  PlexAPI.swift
//  Media App For Plex
//
//  Created by Monster on 23/5/25.
//
import Foundation
import SwiftUI
import Combine

class PlexAPI: ObservableObject {
    static let shared = PlexAPI()
        
    // MARK: - App State (Active Server Management)
    
    @Published var activeServerIndex: Int {
        didSet {
            UserDefaults.standard.set(activeServerIndex, forKey: "activeServerIndex")
        }
    }

    init() {
        self.activeServerIndex = UserDefaults.standard.integer(forKey: "activeServerIndex")
    }

    // MARK: - Credentials Sources
    
    private var plexToken: String? {
        UserDefaults.standard.string(forKey: "plexToken")
    }

    var plexServerTokens: [String] {
        (UserDefaults.standard.array(forKey: "plexServerTokens") as? [String]) ?? []
    }

    var plexBaseUrls: [String] {
        (UserDefaults.standard.array(forKey: "plexBaseUrls") as? [String]) ?? []
    }
    
    var plexServerNames: [String] {
        (UserDefaults.standard.array(forKey: "plexServerNames") as? [String]) ?? []
    }

    private var plexClientIdentifier: String {
        UserDefaults.standard.string(forKey: "plexClientIdentifier") ?? ""
    }

    // MARK: - Active Helpers
    
    var activeToken: String? {
        let tokens = plexServerTokens
        guard !tokens.isEmpty else { return nil }
        return activeServerIndex < tokens.count ? tokens[activeServerIndex] : tokens.first
    }

    var activeBaseUrl: String {
        let urls = plexBaseUrls
        guard !urls.isEmpty else { return "" }
        return activeServerIndex < urls.count ? urls[activeServerIndex] : (urls.first ?? "")
    }

    // MARK: - Save Helpers
    
    static func appendServer(token: String, baseUrl: String, name: String) {
        print("name: \(name)")
        
        var tokens = (UserDefaults.standard.array(forKey: "plexServerTokens") as? [String]) ?? []
        var urls = (UserDefaults.standard.array(forKey: "plexBaseUrls") as? [String]) ?? []
        var names = (UserDefaults.standard.array(forKey: "plexServerNames") as? [String]) ?? []
        
        if let existingIndex = tokens.firstIndex(of: token) {
            // Token đã có → update url và name tại đúng index
            urls[existingIndex] = baseUrl
            names[existingIndex] = name
        } else {
            // Token mới → append vào cả 3 array
            tokens.append(token)
            urls.append(baseUrl)
            names.append(name)
        }
        
        UserDefaults.standard.set(tokens, forKey: "plexServerTokens")
        UserDefaults.standard.set(urls, forKey: "plexBaseUrls")
        UserDefaults.standard.set(names, forKey: "plexServerNames")
    }

    private var plexServerToken: String? {
        UserDefaults.standard.string(forKey: "plexServerToken")
    }
    
    private var plexBaseUrl: String {
        UserDefaults.standard.string(forKey: "plexBaseUrl") ?? ""
    }
    
    let isIpad = UIDevice.current.userInterfaceIdiom == .pad
    
    func request<T: Decodable>(
            path: String,
            queryItems: [URLQueryItem]? = nil,
            responseType: T.Type,
            isDiscover: Bool = false,
            completion: @escaping (Result<T, PlexAPIError>) -> Void
        ) {
            let token = isDiscover ? (plexToken ?? activeToken) : activeToken
            let base = isDiscover ? Environment.discoverBaseURL : activeBaseUrl

            guard let finalToken = token, !base.isEmpty else {
                completion(.failure(.missingToken)); return
            }

            var components = URLComponents(string: base + path)
            components?.queryItems = queryItems
            guard let url = components?.url else { completion(.failure(.invalidURL)); return }

            var req = URLRequest(url: url)
            req.setValue(finalToken, forHTTPHeaderField: "X-Plex-Token")
            req.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: req) { data, _, error in
                if let error = error { completion(.failure(.unknown(error))); return }
                guard let data = data else { completion(.failure(.serverError("No data"))); return }
                do {
                    let decoded = try JSONDecoder().decode(responseType, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }.resume()
        }

        func requestAsync<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil, responseType: T.Type, isDiscover: Bool = false) async throws -> T {
            let token = isDiscover ? (plexToken ?? activeToken) : activeToken
            let base = isDiscover ? Environment.discoverBaseURL : activeBaseUrl
            guard let finalToken = token, !base.isEmpty else { throw PlexAPIError.missingToken }

            var components = URLComponents(string: base + path)
            components?.queryItems = queryItems
            guard let url = components?.url else { throw PlexAPIError.invalidURL }

            var req = URLRequest(url: url)
            req.setValue(finalToken, forHTTPHeaderField: "X-Plex-Token")
            req.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONDecoder().decode(responseType, from: data)
        }

    func fetchLibraries(completion: @escaping (Result<[PlexLibrary], Error>) -> Void) {
        let path = "/library/sections/"
        
        request(path: path, queryItems: nil, responseType: PlexLibraryResponse.self) { result in
            switch result {
            case .success(let data):
                // print("data: \(data)")
                completion(.success(data.mediaContainer.directory))
            case .failure(let err):
                print("err: \(err)")
                completion(.failure(err))
            }
        }
    }
    
    func fetchContinueWatchingHub(completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/hubs/continueWatching"
        let queryItems = [
            URLQueryItem(name: "includeMeta", value: String(1)),
            // URLQueryItem(name: "excludeFields", value: "summary"),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.hub ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchPinCollectionByLibraryId(libraryId: String, completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/hubs/promoted"
        let queryItems = [
            URLQueryItem(name: "contentDirectoryID", value: libraryId),
            URLQueryItem(name: "pinnedContentDirectoryID", value: libraryId),
            URLQueryItem(name: "excludeContinueWatching", value: String(1)),
            URLQueryItem(name: "count", value: String(20)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    completion(.success(data.mediaContainer.hub ?? []))
                case .failure(let err):
                    print(err)
                    completion(.failure(err))
                }
            }
        }
    }
    
    func getPosterURL(url: String?) -> URL? {
        guard let url = url else { return nil }
        var components = URLComponents(string: activeBaseUrl + url)
        components?.queryItems = [URLQueryItem(name: "X-Plex-Token", value: activeToken)]
        guard let url = components?.url else {
            return nil
        }
        
        return url
    }
    
    func getPosterTranscodeURL(url: String?, width: Int, height: Int) -> URL? {
        guard let url = url else { return nil }
        var components = URLComponents(string: activeBaseUrl + "/photo/:/transcode")
        components?.queryItems = [
            URLQueryItem(name: "url", value: String(url.urlEncoded())),
            URLQueryItem(name: "width", value: String(width)),
            URLQueryItem(name: "height", value: String(height)),
            URLQueryItem(name: "minSize", value: String(1)),
            URLQueryItem(name: "upscale", value: String(1)),
            URLQueryItem(name: "X-Plex-Token", value: activeToken)
        ]
        // print("url transcode: \(components)")
        
        guard let url = components?.url else {
            return nil
        }
        
        return url
    }
    
    func fetchMetadataDetail(id: String, completion: @escaping (Result<PlexMetaDataDetail, Error>) -> Void) {
        let path = "/library/metadata/\(id)"
        // print("path: \(path)")
        let queryItems = [
           URLQueryItem(name: "includeOnDeck", value: String(1)),
           URLQueryItem(name: "includeExtras", value: String(1)),
           URLQueryItem(name: "includePopularLeaves", value: String(1)),
           URLQueryItem(name: "includePreferences", value: String(1)),
           URLQueryItem(name: "includeExternalMedia", value: String(1)),
           URLQueryItem(name: "includeReviews", value: String(1)),
           URLQueryItem(name: "includeChapters", value: String(1)),
           URLQueryItem(name: "includeStations", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexMetaDataDetailResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadata[0]))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchMetadataDetailAsync(id: String, isDiscover: Bool = false) async throws -> PlexMetaDataDetail {
        let path = "/library/metadata/\(id)"
        // print("path: \(path)")
        let queryItems = [
           URLQueryItem(name: "includeOnDeck", value: String(1)),
           URLQueryItem(name: "includeExtras", value: String(1)),
           URLQueryItem(name: "includePopularLeaves", value: String(1)),
           URLQueryItem(name: "includePreferences", value: String(1)),
           URLQueryItem(name: "includeExternalMedia", value: String(1)),
           URLQueryItem(name: "includeReviews", value: String(1)),
           URLQueryItem(name: "includeChapters", value: String(1)),
           URLQueryItem(name: "includeStations", value: String(1)),
           URLQueryItem(name: "includeConcerts", value: String(1)),
           URLQueryItem(name: "asyncAugmentMetadata", value: String(1)),
           URLQueryItem(name: "asyncCheckFiles", value: String(0)),
           URLQueryItem(name: "asyncRefreshAnalysis", value: String(1)),
           URLQueryItem(name: "asyncRefreshLocalMediaAgent", value: String(1)),
           URLQueryItem(name: "includeMarkers", value: String(1)),
           URLQueryItem(name: "checkFiles", value: String(1)),
        ]
        
        let response: PlexMetaDataDetailResponse = try await requestAsync(path: path, queryItems: queryItems, responseType: PlexMetaDataDetailResponse.self, isDiscover: isDiscover)
        
        guard let metadata = response.mediaContainer.metadata.first else {
            throw NSError(domain: "No metadata found", code: -1)
        }
        // print("metadata.medias: \(metadata.medias)")
        
        return metadata
    }
    
    func fetchMetadataAsync(id: String, isDiscover: Bool = false) async throws -> PlexMetaData {
        let path = "/library/metadata/\(id)"
        // print("path: \(path)")
        let queryItems = [
           URLQueryItem(name: "includeOnDeck", value: String(1)),
           URLQueryItem(name: "includeExtras", value: String(1)),
           URLQueryItem(name: "includePopularLeaves", value: String(1)),
           URLQueryItem(name: "includePreferences", value: String(1)),
           URLQueryItem(name: "includeExternalMedia", value: String(1)),
           URLQueryItem(name: "includeReviews", value: String(1)),
           URLQueryItem(name: "includeChapters", value: String(1)),
           URLQueryItem(name: "includeStations", value: String(1)),
           URLQueryItem(name: "includeConcerts", value: String(1)),
           URLQueryItem(name: "asyncAugmentMetadata", value: String(1)),
           URLQueryItem(name: "asyncCheckFiles", value: String(1)),
           URLQueryItem(name: "asyncRefreshAnalysis", value: String(1)),
           URLQueryItem(name: "asyncRefreshLocalMediaAgent", value: String(1)),
           URLQueryItem(name: "includeMarkers", value: String(1)),
        ]
        
        let response: PlexMetadataResponse = try await requestAsync(path: path, queryItems: queryItems, responseType: PlexMetadataResponse.self, isDiscover: isDiscover)
        
        guard let metadata = response.mediaContainer.metadata.first else {
            throw NSError(domain: "No metadata found", code: -1)
        }
        // print("metadata.medias: \(metadata.medias)")
        
        return metadata
    }
    
    func getVideoURL(urlString: String) -> String {
        return activeBaseUrl + urlString + "?X-Plex-Token=\(activeToken ?? "")"
    }
    
    func getDiscoverVideoUrl(urlString: String) -> String {
        return activeBaseUrl + urlString + "&X-Plex-Token=\(activeToken ?? "")"
    }
    
    func sendTimelineUpdate(ratingKey: String, time: Int, state: String, duration: Int, playbackSessionId: String) {
        var components = URLComponents(string: "\(activeBaseUrl)/:/timeline")!
        let isPaused = (state == "paused") ? "1" : "0"
        let infoDict = Bundle.main.infoDictionary
        let appVersion = infoDict?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = infoDict?["CFBundleVersion"] as? String ?? "unknown"
        let fullVersion = "v\(appVersion) (\(buildNumber))"
        components.queryItems = [
            URLQueryItem(name: "ratingKey", value: ratingKey),
            URLQueryItem(name: "key", value: ("/library/metadata/\(ratingKey)").urlEncoded()),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "isPaused", value: isPaused),
            URLQueryItem(name: "protocol", value: "http"),
            URLQueryItem(name: "duration", value: "\(duration)"),
            URLQueryItem(name: "time", value: "\(time)"),
            URLQueryItem(name: "hasMDE", value: "1"),
            URLQueryItem(name: "playQueueItemID", value: "0"),
            URLQueryItem(name: "row", value: "0"),
            URLQueryItem(name: "col", value: "0"),
            URLQueryItem(name: "playbackTime", value: "0"),
            URLQueryItem(name: "containerKey", value: "/playQueues/\(ratingKey)?own=1&window=100"),
            URLQueryItem(name: "X-Plex-Token", value: activeToken),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: plexClientIdentifier),
            URLQueryItem(name: "X-Plex-Product", value: "bLoop \(fullVersion)"),
            URLQueryItem(name: "X-Plex-Platform", value: "bLoop-AppleTV"),
            URLQueryItem(name: "X-Plex-Playback-Session-Id", value: playbackSessionId),
        ]

        guard let url = components.url else { return }

       let task = URLSession.shared.dataTask(with: url)
       task.resume()
    }
    
    func fetchMetadataByKeyword(keyword: String, completion: @escaping (Result<[PlexSearchItem], Error>) -> Void) {
        let path = "/library/search"
        let queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "limit", value: String(100)),
            URLQueryItem(name: "searchTypes", value: String("movies,people,tv")),
            URLQueryItem(name: "includeCollections", value: String(1)),
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "includeSummary", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexSearchItemResponse.self) { result in
            switch result {
            case .success(let data):
                data.mediaContainer.searchResult.forEach { item in
                    let title = item.metadata?.title ?? item.directory?.title ?? "Unknown"
                    let thumb = item.metadata?.thumbnail ?? item.directory?.thumb ?? "None"
                }
                completion(.success(data.mediaContainer.searchResult))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchExternalMetadataByKeyword(keyword: String, completion: @escaping (Result<([PlexSearchItem], [String]), Error>) -> Void) {
        let path = "/library/search"
        let queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "limit", value: String(30)),
            URLQueryItem(name: "searchTypes", value: "movies,people,tv"),
            URLQueryItem(name: "includeCollections", value: String(1)),
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "searchProviders", value: "discover"),
            URLQueryItem(name: "includeSummary", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexExternalSearchItemResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                // completion(.success(data.mediaContainer.searchResult))
                let suggestedTerms = data.mediaContainer.suggestedTerms
                let items = data.mediaContainer.searchResults.first?.searchResult ?? []
                // let items: [PlexSearchItem] = []
                let peopleItems = data.mediaContainer.searchResults
                    .first(where: { $0.id == "people" })?
                    .searchResult ?? []
                let combinedItems = items + peopleItems
                completion(.success((combinedItems, suggestedTerms)))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchAllLeaves(id: String, completion: @escaping (Result<[PlexMetaDataDetail], Error>) -> Void) {
        let path = "/library/metadata/\(id)/allLeaves"
        let queryItems = [
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexAllLeavesResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchPlayQueues(id: String, completion: @escaping (Result<[PlexMetaDataDetail], Error>) -> Void) {
        let path = "/library/metadata/\(id)/allLeaves"
        let queryItems = [
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
        ]
        request(path: path, queryItems: queryItems, responseType: PlexAllLeavesResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchWatchlist(offset: Int, size: Int, type: String, year: String, country: String, sort: String, order: String, completion: @escaping (Result<[PlexMetaData], Error>) -> Void) {
        let path = "/library/sections/watchlist/all"
        var queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "includeAdvanced", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "X-Plex-Container-Start", value: String(offset)),
            URLQueryItem(name: "X-Plex-Container-Size", value: String(size)),
        ]
        
        if country != "" || country != "99" {
            queryItems.append(URLQueryItem(name: "country", value: "\(country)"))
        }
        
        if sort != "" {
            queryItems.append(URLQueryItem(name: "sort", value: "\(sort):\(order)"))
        }
        
        if year != "" {
            queryItems.append(URLQueryItem(name: "year", value: "\(year)"))
        }
        
        request(path: path, queryItems: queryItems, responseType: PlexWatchlistResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchWatchFromTheseLocation(guid: String, completion: @escaping (Result<[PlexMetaData], Error>) -> Void) {
        let path = "/library/all"
        let queryItems = [
            // URLQueryItem(name: "type", value: String(2)),
            URLQueryItem(name: "guid", value: guid),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexWatchlistResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchUserState(ratingKey: String, completion: @escaping (Result<PlexUserState, Error>) -> Void) {
        let path = "/library/metadata/\(ratingKey)/userState"
        let queryItems = [
            URLQueryItem(name: "includeMeta", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexUserStateResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.userState[0]))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func addToWatchlist(ratingKey: String) {
        var components = URLComponents(string: "\(Environment.discoverBaseURL)/actions/addToWatchlist")!

        components.queryItems = [
            URLQueryItem(name: "ratingKey", value: ratingKey),
            URLQueryItem(name: "X-Plex-Token", value: plexToken),
        ]

        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(plexToken, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")

       let task = URLSession.shared.dataTask(with: request)
       task.resume()
    }
    
    func removeFromWatchlist(ratingKey: String) {
        var components = URLComponents(string: "\(Environment.discoverBaseURL)/actions/removeFromWatchlist")!

        components.queryItems = [
            URLQueryItem(name: "ratingKey", value: ratingKey),
            URLQueryItem(name: "X-Plex-Token", value: plexToken),
        ]

        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(plexToken, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")

       let task = URLSession.shared.dataTask(with: request)
       task.resume()
    }
    
    func fetchRelatedByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/library/metadata/\(ratingKey)/related"
        let queryItems = [
            URLQueryItem(name: "includeAugmentations", value: String(1)),
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.hub ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchPeopleRelatedByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/library/people/\(ratingKey)/related"
        let queryItems = [
            URLQueryItem(name: "includeAugmentations", value: String(1)),
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.hub ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchPeopleCreditsByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping (Result<[FilmographyGroup], Error>) -> Void) {
        let path = "/library/people/\(ratingKey)/credits"
        let queryItems = [
            URLQueryItem(name: "includeAugmentations", value: String(1)),
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexFilmographyResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.creditGroup ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchMetadatasByHubKey(key: String, offset: Int = 0, size: Int = 36, isDiscover: Bool, completion: @escaping (Result<[PlexMetaData], Error>) -> Void) {
        guard var components = URLComponents(string: key) else {
            completion(.failure(NSError(domain: "Invalid hubKey", code: -1)))
            return
        }

        let path = components.path
        var queryItems = components.queryItems ?? []

        queryItems += [
            URLQueryItem(name: "includeMeta", value: "1"),
            URLQueryItem(name: "X-Plex-Container-Start", value: String(offset)),
            URLQueryItem(name: "X-Plex-Container-Size", value: String(size)),
        ]
        
        print("path: \(path)")
        print("queryItems: \(queryItems)")
        
        request(path: path, queryItems: queryItems, responseType: PlexWatchlistResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchDirectoriesByHubKey(key: String, offset: Int = 0, size: Int = 36, isDiscover: Bool, completion: @escaping (Result<[PlexDirectory], Error>) -> Void) {
        guard var components = URLComponents(string: key) else {
            completion(.failure(NSError(domain: "Invalid hubKey", code: -1)))
            return
        }

        let path = components.path
        var queryItems = components.queryItems ?? []

        queryItems += [
            URLQueryItem(name: "includeMeta", value: "1"),
            URLQueryItem(name: "X-Plex-Container-Start", value: String(offset)),
            URLQueryItem(name: "X-Plex-Container-Size", value: String(size)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexDirectoryResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.directories))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchActorDetail(id: String, completion: @escaping (Result<PlexActorDetail, Error>) -> Void) {
        let path = "/library/people/\(id)"
        let queryItems = [
            URLQueryItem(name: "includeConcerts", value: String(1)),
            URLQueryItem(name: "includeExtras", value: String(1)),
            URLQueryItem(name: "includeOnDeck", value: String(1)),
            URLQueryItem(name: "includePopularLeaves", value: String(1)),
            URLQueryItem(name: "includePreferences", value: String(1)),
            URLQueryItem(name: "includeOnDeck", value: String(1)),
            URLQueryItem(name: "includeReviews", value: String(1)),
            URLQueryItem(name: "includeChapters", value: String(1)),
            URLQueryItem(name: "includeStations", value: String(1)),
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "asyncAugmentMetadata", value: String(1)),
            URLQueryItem(name: "asyncCheckFiles", value: String(1)),
            URLQueryItem(name: "asyncRefreshAnalysis", value: String(1)),
            URLQueryItem(name: "asyncRefreshLocalMediaAgent", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexActorDetailResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadata[0]))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchCategories(libraryId: String, completion: @escaping (Result<[PlexCategory], Error>) -> Void) {
        let path = "/library/sections/\(libraryId)/categories"
        let queryItems = [
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "includeCollections", value: String(1)),
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "includeAdvanced", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexCategoriesResponse.self) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.directory))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchCategoryThumbnail(urlString: String) -> URL? {
        guard let token = activeToken else {
            return URL(string: "")
        }
        // print("thumbnail url from fetchCategoryThumbnail: \(plexBaseUrl)\(urlString)&X-Plex-Token=\(token)")
        return URL(string: "\(activeToken)\(urlString)&X-Plex-Token=\(token)")
    }
    
    func fetchDiscoverHomeHub(completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/hubs/sections/home"
        let queryItems = [
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "count", value: String(12)),
            URLQueryItem(name: "includeLibraryPlaylists", value: String(1)),
            URLQueryItem(name: "includeStations", value: String(1)),
            URLQueryItem(name: "includeRecentChannels", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.hub ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchHubsByLibraryId(libraryId: String, completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/hubs/sections/\(libraryId)"
        let queryItems = [
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "count", value: String(12)),
            URLQueryItem(name: "excludeContinueWatching", value: String(1)),
            URLQueryItem(name: "includeLibraryPlaylists", value: String(1)),
            URLQueryItem(name: "includeStations", value: String(1)),
            URLQueryItem(name: "includeRecentChannels", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self, isDiscover: false) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    completion(.success(data.mediaContainer.hub ?? []))
                case .failure(let err):
                    print(err)
                    completion(.failure(err))
                }
            }
        }
    }
    
    func fetchDiscoverHubByHubkey(hubKey: String, completion: @escaping (Result<[PlexHomeCollection], Error>) -> Void) {
        let path = "/\(hubKey)"
        let queryItems = [
            URLQueryItem(name: "includeExternalMetadata", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "count", value: String(12)),
            URLQueryItem(name: "includeLibraryPlaylists", value: String(1)),
            URLQueryItem(name: "includeStations", value: String(1)),
            URLQueryItem(name: "includeRecentChannels", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexHomeCollectionResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.hub ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchMetadatasByGenre(genreId: Int, completion: @escaping (Result<[PlexMetaData], Error>) -> Void) {
        let path = "/library/all"
        let queryItems = [
            URLQueryItem(name: "type", value: String(1)),
            URLQueryItem(name: "sort", value: "titleSort"),
            URLQueryItem(name: "genre", value: String(genreId)),
            URLQueryItem(name: "includeCollections", value: String(12)),
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "includeAdvanced", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexWatchlistResponse.self, isDiscover: true) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func toggleWatchState(id: String, isMarkAsUnwatch: Bool) {
        let endpoint = isMarkAsUnwatch ? "unscrobble" : "scrobble"
        let urlString = "\(activeBaseUrl)/:/\(endpoint)?key=\(id)&identifier=com.plexapp.plugins.library"
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue(activeToken, forHTTPHeaderField: "X-Plex-Token")
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func removeFromContinueWatching(id: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        var components = URLComponents(string: "\(activeBaseUrl)/actions/removeFromContinueWatching")!

        components.queryItems = [
            URLQueryItem(name: "ratingKey", value: id),
            URLQueryItem(name: "X-Plex-Token", value: activeToken),
        ]

        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(activeToken, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(plexClientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            print("response: \(response)")
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                completion(.failure(URLError(.badServerResponse)))
            }
        }
        task.resume()
    }
    
    func fetchTags(libraryId: String, completion: @escaping (Result<[PlexTag], Error>) -> Void) {
        let path = "/library/sections/\(libraryId)/collections"
        let queryItems = [
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "includeAdvanced", value: String(1)),
            URLQueryItem(name: "includeCollections", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexTagResponse.self, isDiscover: false) { result in
            switch result {
            case .success(let data):
                
                completion(.success(data.mediaContainer.metadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchSeasonalMetadatas(libraryId: String, completion: @escaping (Result<[PlexMetaData], Error>) -> Void) {
        let path = "/library/sections/\(libraryId)/collections"
        let queryItems = [
            URLQueryItem(name: "includeExternalMedia", value: String(1)),
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "includeAdvanced", value: String(1)),
            URLQueryItem(name: "includeCollections", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexMetadataResponse.self, isDiscover: false) { result in
            switch result {
            case .success(let data):
                let suffix = "_<season>"
                let seasonalMetadatas = data.mediaContainer.metadata
                    .filter { $0.title.hasSuffix(suffix) == true }
                completion(.success(seasonalMetadatas))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
    
    func fetchChildren(ratingKey: String, isDiscover: Bool, completion: @escaping (Result<[PlexMetaDataDetail], Error>) -> Void) {
        let path = "/library/metadata/\(ratingKey)/children"
        let queryItems = [
            URLQueryItem(name: "includeMeta", value: String(1)),
            URLQueryItem(name: "includeSummary", value: String(1)),
        ]
        
        request(path: path, queryItems: queryItems, responseType: PlexAllLeavesResponse.self, isDiscover: isDiscover) { result in
            switch result {
            case .success(let data):
                completion(.success(data.mediaContainer.metadatas ?? []))
            case .failure(let err):
                print(err)
                completion(.failure(err))
            }
        }
    }
}
