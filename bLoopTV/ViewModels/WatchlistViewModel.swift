//
//  WatchlistViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 20/6/25.
//


import Foundation
import Combine

class WatchlistViewModel: ObservableObject {
    private var isLoading = false

    func fetchWatchlist(
        offset: Int,
        size: Int,
        type: String = "99",
        year: String = "",
        country: String = "",
        sort: String = "",
        order: String = "",
        completion: @escaping ([PlexMetaData]) -> Void = { _ in }
    ) {
        PlexAPI.shared.fetchWatchlist(offset: offset, size: size, type: type, year: year, country: country, sort: sort, order: order) { result in
            switch result {
            case .success(let metadatas):
                completion(metadatas)
            case .failure(let error):
                print("Error from fetchWatchlist: \(error.localizedDescription)")
            }
        }
    }
}

