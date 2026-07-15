//
//  NavigationManager.swift
//  VuaPhimBui
//
//  Created by Monster on 28/6/25.
//

import SwiftUI
import SDWebImageSwiftUI
import Combine

class NavigationPathManager: ObservableObject {
    @Published var path: [NavigationDestination] = []
    static let shared = NavigationPathManager()

    func push(_ destination: NavigationDestination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func reset() {
        path.removeAll()
        
        SDWebImageManager.shared.cancelAll()
        SDImageCache.shared.clearMemory()
    }
    
    var isLastFilterMovie: Bool {
        if case .filterMovie = path.last {
            return true
        }
        return false
    }
    
    func replaceLastFilterMovie(query: String) {
        if case .filterMovie = path.last {
            path[path.count - 1] = .filterMovie(filterQuery: query)
        } else {
            push(.filterMovie(filterQuery: query))
        }
    }
    
    func navigateToMovie(movieId: String) {
        print("movie should navigate: \(movieId)")
        Task {
            do {
                let metadata = try await PlexAPI.shared.fetchMetadataAsync(id: movieId)
                print("metadata: \(metadata)")
                push(.movieDetail(metadata: metadata, isDiscover: false))
//                DispatchQueue.main.async {
//                    
//                }
                
            } catch {
                print("error fetch detail id \(movieId):", error)
            }
        }
    }
}
