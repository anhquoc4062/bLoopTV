//
//  CollectionViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 26/6/25.
//

import Foundation
import Combine

class CollectionViewModel: ObservableObject {
    private var isLoading = false
    
    func fetchMetadatasByHubKey(key: String, offset: Int, size: Int, isDiscover: Bool, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        print("key from fetchMetadatasByHubKey: \(key)")
        PlexAPI.shared.fetchMetadatasByHubKey(key: key, offset: offset, size: size, isDiscover: isDiscover) { result in
            switch result {
            case .success(let collections):
                completion(collections)
            case .failure(let error):
                print("Error from fetchMetadatasByHubKey in collectionView: \(error.localizedDescription)")
            }
        }
    }
}
