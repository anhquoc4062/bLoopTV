//
//  DiscoverViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 5/7/25.
//
import Foundation
import Combine

enum PlexHubCollection {
    case home(PlexHomeCollection)
    case directory(PlexDirectoryCollection)
}

class DiscoverViewModel: ObservableObject {
    @Published var listHub: [PlexHomeCollection] = []
    @Published var metadataCollection: [String: PlexHomeCollection] = [:]
    @Published var directoryCollection: [String: PlexDirectoryCollection] = [:]
    
    func fetchDiscoverHub(hubKey: String) {
        let fetch: (@escaping (Result<[PlexHomeCollection], Error>) -> Void) -> Void =
            hubKey != ""
            ? { completion in PlexAPI.shared.fetchDiscoverHubByHubkey(hubKey: hubKey, completion: completion) }
            : { completion in PlexAPI.shared.fetchDiscoverHomeHub(completion: completion) }
        fetch { result in
            switch result {
            case .success(let collections):
                DispatchQueue.main.async {
                    self.listHub = collections
                    for collection in collections {
                        // self.hubCollection[collection.id] = collection
                        
                        if collection.title != "Trending On Plex" {
                            if collection.type == "directory" {
                                self.directoryCollection[collection.id] = PlexDirectoryCollection(
                                    id: collection.id,
                                    key: collection.key,
                                    title: collection.title,
                                    type: collection.type,
                                    directories: []
                                )
                                self.fetchDirectoryByHubKey(key: collection.key, offset: 0, size: 36){ directories in
                                    if var existingCollection = self.directoryCollection[collection.id]?.directories {
                                        existingCollection.append(contentsOf: directories)
                                        self.directoryCollection[collection.id]?.directories = existingCollection
                                    } else {
                                        self.directoryCollection[collection.id]?.directories = directories
                                    }
                                    
                                }
                            } else {
                                self.metadataCollection[collection.id] = collection
                                self.fetchMetadatasByHubKey(key: collection.key, offset: 0, size: 36){ metadatas in
                                    if var existingCollection = self.metadataCollection[collection.id]?.metadatas {
                                        existingCollection.append(contentsOf: metadatas)
                                        self.metadataCollection[collection.id]?.metadatas = existingCollection
                                    } else {
                                        self.metadataCollection[collection.id]?.metadatas = metadatas
                                    }
                                    
                                }
                            }
                        }
                       
                    }
                }
            case .failure(let error):
                print("Error from fetchDiscoverHomeHub: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchMetadatasByHubKey(key: String, offset: Int, size: Int, completion: @escaping ([PlexMetaData]) -> Void = { _ in }) {
        PlexAPI.shared.fetchMetadatasByHubKey(key: key, offset: offset, size: size, isDiscover: true) { result in
            switch result {
            case .success(let collections):
                DispatchQueue.main.async {
                    completion(collections)
                }
            case .failure(let error):
                print("Error from fetchMetadatasByHubKey \(key): \(error.localizedDescription)")
            }
        }
    }
    
    func fetchDirectoryByHubKey(key: String, offset: Int, size: Int, completion: @escaping ([PlexDirectory]) -> Void = { _ in }) {
        PlexAPI.shared.fetchDirectoriesByHubKey(key: key, offset: offset, size: size, isDiscover: true) { result in
            switch result {
            case .success(let collections):
                DispatchQueue.main.async {
                    completion(collections)
                }
            case .failure(let error):
                print("Error from fetchDirectoryByHubKey \(key): \(error.localizedDescription)")
            }
        }
    }
}
