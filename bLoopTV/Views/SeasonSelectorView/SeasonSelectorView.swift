//
//  SeasonSelectorView.swift
//  bLoopTV
//
//  Rewritten for tvOS — card layout, focus engine optimized
//

import SwiftUI
import SDWebImageSwiftUI

// MARK: - Main View

struct SeasonSelectorView: View {
    let id: String
    let isDiscover: Bool
    @ObservedObject var movieDetailViewModel: MovieDetailViewModel
    let onSelectEpisode: (Episode) -> Void

    @StateObject private var viewModel = SeasonViewModel()
    @State private var isInitLoad = true
    @Binding var triggerReload: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !viewModel.seasons.isEmpty {
                SeasonTabBar(
                    seasons: viewModel.seasons,
                    selectedSeasonID: $viewModel.selectedSeasonID
                )
            }

            episodeContent.focusSection()
        }
        .onFirstAppear {
            isDiscover ? loadSeasons() : loadSeasonEpisodeData()
        }
        .onChange(of: movieDetailViewModel.selectedMetadata?.episodeIndex) { _ in
            handleSelectedMetadataChange()
        }
        .onChange(of: triggerReload) { newValue in
            guard !isDiscover, newValue else { return }
            loadSeasonEpisodeData()
            DispatchQueue.main.async { triggerReload = false }
        }
        .onChange(of: viewModel.selectedSeasonID) { newID in
            guard isDiscover, let newID,
                  let season = viewModel.seasons.first(where: { $0.id == newID })
            else { return }
            loadEpisodes(season: season)
        }
    }

    // MARK: - Episode Content

    @ViewBuilder
    private var episodeContent: some View {
        if let season = viewModel.seasons.first(where: { $0.id == viewModel.selectedSeasonID }) {
            if season.episodes.isEmpty {
                loadingPlaceholder
            } else {
                EpisodeCardGrid(
                    episodes: season.episodes,
                    selectedMetadata: movieDetailViewModel.selectedMetadata,
                    onSelectEpisode: onSelectEpisode
                )
            }
        }
    }

    private var loadingPlaceholder: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color("VArtThemeColor")))
                .scaleEffect(2)
            Spacer()
        }
        .frame(height: 300)
    }

    // MARK: - Data Loading

    private func handleSelectedMetadataChange() {
        viewModel.selectedSeasonID = movieDetailViewModel.selectedMetadata?.seasonIndex
        guard isInitLoad, let id = movieDetailViewModel.selectedMetadata?.id else {
            isInitLoad = false
            return
        }
        // Scrolling is handled inside EpisodeCardGrid via ScrollViewReader
        NotificationCenter.default.post(
            name: .scrollToEpisode,
            object: id
        )
        isInitLoad = false
    }

    private func loadSeasonEpisodeData() {
        viewModel.fetchAllLeaves(
            id: id,
            currentSeasonIndex: movieDetailViewModel.selectedMetadata?.seasonIndex ?? 1
        ) { episodes in
            DispatchQueue.main.async {
                movieDetailViewModel.episodes = episodes
            }
        }
    }

    private func loadSeasons() {
        viewModel.fetchChildren(ratingKey: id, type: "season") { children in
            let seasons = children.compactMap { child -> Season? in
                guard case let .season(s) = child else { return nil }
                return s
            }
            DispatchQueue.main.async {
                viewModel.seasons = seasons
                viewModel.selectedSeasonID = 1
            }
        }
    }

    private func loadEpisodes(season: Season) {
        viewModel.fetchChildren(ratingKey: season.ratingKey ?? "", type: "episode") { children in
            let episodes = children.compactMap { child -> Episode? in
                guard case let .episode(e) = child else { return nil }
                return e
            }
            guard let index = viewModel.seasons.firstIndex(where: { $0.id == season.id }) else { return }
            DispatchQueue.main.async {
                var updated = viewModel.seasons[index]
                updated.episodes = episodes
                viewModel.seasons[index] = updated
            }
        }
    }
}

// MARK: - Season Tab Bar

private struct SeasonTabBar: View {
    let seasons: [Season]
    @Binding var selectedSeasonID: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(seasons) { season in
                    SeasonTabButton(
                        season: season,
                        isSelected: selectedSeasonID == season.id
                    ) {
                        selectedSeasonID = season.id
                    }
                }
            }
            // .padding(.horizontal, 48)
            .padding(.vertical, 8)
        }
    }
}

private struct SeasonTabButton: View {
    let season: Season
    let isSelected: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Text(season.name)
                .font(.system(size: 28, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Color("VArtThemeColor") : .secondary)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background {
                    if isSelected || isFocused {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("VArtThemeColor").opacity(isFocused ? 0.25 : 0.12))
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color("VArtThemeColor"), lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        // .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

// MARK: - Episode Card Grid

private struct EpisodeCardGrid: View {
    let episodes: [Episode]
    let selectedMetadata: MetadataSelected?
    let onSelectEpisode: (Episode) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 50) {
                    ForEach(episodes) { episode in
                        EpisodeCard(
                            episode: episode,
                            isPlaying: episode.id == selectedMetadata?.id,
                            onSelect: { onSelectEpisode(episode) }
                        )
                        .id(episode.id)
                    }
                }
                // .padding(.horizontal, 48)
                .padding(.vertical, 20)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .scrollToEpisode)
            ) { notification in
                guard let episodeID = notification.object as? String else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(episodeID, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Episode Card

private struct EpisodeCard: View {
    let episode: Episode
    let isPlaying: Bool
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    private let cardWidth: CGFloat = 420
    private let cardHeight: CGFloat = 236 // 16:9

    var body: some View {
        VStack {
            Button(action: onSelect) {
                thumbnailView
                .frame(width: cardWidth)
            }
            .buttonStyle(.card)
            .focused($isFocused)
            // .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isFocused)
//            .shadow(
//                color: isFocused ? Color("VArtThemeColor").opacity(0.5) : .black.opacity(0.3),
//                radius: isFocused ? 24 : 8,
//                y: isFocused ? 12 : 4
//            )
            
            metadataView
                .padding(.top, 12).opacity(isFocused ? 1 : 0.8)
        }
        
    }

    // MARK: Thumbnail

    private var thumbnailView: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            WebImage(url: episode.thumbnailURL, options: [.scaleDownLargeImages]) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                    }
            }
            .cancelOnDisappear(true)
            .transition(.fade(duration: 0.4))
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .cornerRadius(14)

            // Playing indicator border
            if isPlaying {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color("VArtThemeColor"), lineWidth: 4)
                    .frame(width: cardWidth, height: cardHeight)
            }

            // Focus border
//            if isFocused {
//                RoundedRectangle(cornerRadius: 14)
//                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
//                    .frame(width: cardWidth, height: cardHeight)
//            }

            // Upcoming release overlay
            if let releaseDate = episode.originallyAvailableAtDate, releaseDate > Date() {
                upcomingBadge(date: releaseDate)
            }

            // Bottom gradient + progress
            VStack {
                Spacer()
                bottomOverlay
            }
            .frame(width: cardWidth, height: cardHeight)
            .cornerRadius(14)

            // Watched badge
            if episode.isWatched {
                watchedBadge
                    .offset(x: -10, y: 10)
            }

            // Now playing badge
            if isPlaying {
                nowPlayingBadge
                    .offset(x: -10, y: cardHeight - 40)
            }
        }
    }

    private func upcomingBadge(date: Date) -> some View {
        Text("Ra mắt \(date.toDMYString())")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color("VArtThemeColor"))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(12)
    }

    private var bottomOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 70)
        .cornerRadius(14)
    }

    private var watchedBadge: some View {
        ZStack {
            Circle()
                .fill(Color("VArtThemeColor"))
                .frame(width: 32, height: 32)
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color("ButtonText"))
        }
    }

    private var nowPlayingBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
            Text("Đang phát")
                .font(.system(size: 18, weight: .semibold))
        }
        .foregroundColor(Color("ButtonText"))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color("VArtThemeColor"), in: Capsule())
    }

    // MARK: Metadata

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mùa \(episode.seasonIndex) • Tập \(episode.episodeIndex)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color("VArtThemeColor"))

            Text(episode.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: cardWidth, alignment: .leading)

            if !episode.summary.isEmpty {
                Text(episode.summary)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let scrollToEpisode = Notification.Name("scrollToEpisode")
}
