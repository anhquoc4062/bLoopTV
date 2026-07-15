//
//  ProfileInfoTabViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//
import SwiftUI
import Combine

class ProfileInfoTabViewModel: ObservableObject {
    @Published var userStatsData: PlexUserStats? = nil
    @Published var listWatchHistory: [PlexMetaData] = []
    
    func fetchUserStats(username: String) {
        PlexCommunityAPI.shared.fetchUserStats(username: username) { result in
            switch result {
            case .success(let userStats):
                DispatchQueue.main.async {
                    self.userStatsData = userStats
                }
            case .failure(let err):
                print("err fetchUserStats: \(err)")
            }
        }
        
    }
    
    func fetchWatchHistory(uuid: String) {
        PlexCommunityAPI.shared.fetchWatchHistory(uuid: uuid) { result in
            switch result {
            case .success(let watchHistory):
                DispatchQueue.main.async {
                    self.listWatchHistory = watchHistory
                }
            case .failure(let err):
                print("err fetchWatchHistory: \(err)")
            }
        }
        
    }
}
