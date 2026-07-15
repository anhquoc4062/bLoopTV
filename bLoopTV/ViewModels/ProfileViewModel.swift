//
//  ProfileViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 8/7/25.
//

import SwiftUI
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userDetailData: PlexUserDetailData? = nil
    
    func fetchUserDetail(username: String) {
        PlexCommunityAPI.shared.fetchUserDetail(username: username) { result in
            switch result {
            case .success(let userDetailData):
                DispatchQueue.main.async {
                    self.userDetailData = userDetailData
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
        
    }
}
