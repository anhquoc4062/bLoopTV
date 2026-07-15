//
//  VLCPlayerViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 25/5/25.
//

import Foundation
import Combine

class VLCPlayerViewModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var listSubtitle: [PlexMediaPartStream] = []
    
    func updateListSubtitle(subtitles: [PlexMediaPartStream]) {
        listSubtitle = subtitles
    }
    
    func getVideoURL(url: String) -> String {
        return PlexAPI.shared.getVideoURL(urlString: url)
    }
}
