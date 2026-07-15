//
//  SheetManger.swift
//  VuaPhimBui
//
//  Created by Monster on 22/7/25.
//
import SwiftUI
import Combine

class SheetManger: ObservableObject {
    @Published var isPresentingInviteSheet = false
    @Published var isPresentingSharingSheet = false
    @Published var isPresentingRatingSheet = false
    @Published var isPresentingFilteringSheet = false
    @Published var metadata: PlexMetaData? = nil
    @Published var currentFilterQuery: String? = nil
    
    func showInviteSheet(with metadata: PlexMetaData) {
        self.metadata = metadata
        self.isPresentingInviteSheet = true
    }

    func showSharingSheet(with metadata: PlexMetaData) {
        self.metadata = metadata
        self.isPresentingSharingSheet = true
    }

    func showRatingSheet(with metadata: PlexMetaData) {
        self.metadata = metadata
        self.isPresentingRatingSheet = true
    }
    
    func showFilterSheet() {
        isPresentingFilteringSheet = true
    }
    
    func updateCurrentFilterQuery(query: String? = nil) {
        currentFilterQuery = query
    }
    
    func dismissFilterSheet() {
        isPresentingFilteringSheet = false
        currentFilterQuery = nil
    }
}
