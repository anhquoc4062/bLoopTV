//
//  ActorDetailViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 3/7/25.
//

import Foundation
import Combine

class ActorDetailViewModel: ObservableObject {
    @Published var actorDetail: PlexActorDetail?
    
    func fetchActorDetail(id: String, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        PlexAPI.shared.fetchActorDetail(id: id) { result in
            switch result {
            case .success(let actorDetail):
                DispatchQueue.main.async {
                    self.actorDetail = actorDetail
                }
            case .failure(let error):
                print("Error from fetchActorDetail: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchRelatedByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping ([PlexHomeCollection]) -> Void = { _ in }) {
        PlexAPI.shared.fetchPeopleRelatedByRatingKey(ratingKey: ratingKey, isDiscover: isDiscover) { result in
            switch result {
            case .success(let collections):
                completion(collections)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchMetadatasByHubKey(key: String, offset: Int, size: Int, isDiscover: Bool, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        PlexAPI.shared.fetchMetadatasByHubKey(key: key, offset: offset, size: size, isDiscover: isDiscover) { result in
            switch result {
            case .success(let collections):
                completion(collections)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchPeopleCreditsByRatingKey(ratingKey: String, isDiscover: Bool, completion: @escaping ([FilmographyGroup]) -> Void = { _ in }) {
        PlexAPI.shared.fetchPeopleCreditsByRatingKey(ratingKey: ratingKey, isDiscover: isDiscover) { result in
            switch result {
            case .success(let filmographyGroup):
                completion(filmographyGroup)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
}
