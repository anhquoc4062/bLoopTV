//
//  FilterSheetViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 8/9/25.
//

import SwiftUI
import Combine

struct FilterOption: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
}

extension FilterOption {
    static let all = FilterOption(id: "99", title: "Tất cả")
    static let allType = FilterOption(id: "1,2", title: "Tất cả loại")
    static let defaultSort = FilterOption(id: "addedAt", title: "Mới thêm vào")
}

class FilterSheetViewModel: ObservableObject {
    @Published var genres: [FilterOption] = []

    func mergeAllCachedCategories() -> [PlexCategory] {
        var merged: [PlexCategory] = []

        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("cachedCategories_") {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([PlexCategory].self, from: data) {
                merged.append(contentsOf: decoded)
            }
        }

        return Array(
            Dictionary(grouping: merged, by: { $0.id }).compactMap { $0.value.first }
        ).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

