//
//  MovieDetailView.swift
//  Media App For Plex
//
//  Created by Monster on 25/5/25.
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI
import Combine

class BlurColors: ObservableObject {
    @Published var topLeft: String = "#351C1C"
    @Published var topRight: String = "#351C1C"
    @Published var bottomRight: String = "#351C1C"
    @Published var bottomLeft: String = "#351C1C"
}

struct MovieDetailViewTest2: View {
    // @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject var navManager: NavigationPathManager
    
    let metadata: PlexMetaData
    let isDiscover: Bool
    let trigger: CGFloat = 0
    let tolerance: CGFloat = 0.0001
    let thumnailHeight: CGFloat = 400.0
    let isIpad: Bool = true

    @State private var scrollOffset: CGFloat = 0
    @State private var gemetrySizeWidth: CGFloat = 0
    @State private var showTitle: Bool = false
    @State private var showVersionPopup = false
    @State private var isWatchlisted: Bool = false
    @State private var isLoadingWatchlisted: Bool = true
    @State private var currentPlexRatingKey: String = ""
    @State private var showVideo = false
    @State private var playMusic = false
    @State private var isReadyToPlayVideo = false
    @State private var videoTrailerUrl: String? = nil
    @State private var themeMusicUrl: URL? = nil
    @State private var isExpanded = false
    @State private var isMutedTrailer = true
    @State private var hasFetchedRelated = false
    @State private var showShareSheet = false
    @State private var shouldReloadSeason = false
    @State private var has4KVersion = false
    @State private var originallyAvailableAtDate: Date? = nil

    
    @State private var listVersion: [PlexMedia] = []
    @State private var listLocation: [PlexMetaData] = []
    @State private var listTrailer: [PlexMedia] = []
    @State private var listRole: [PlexActor] = []
    @State private var listDirector: [PlexActor] = []
    
    @State private var selectedVersionPart: PlexMediaPart?
    @State private var viewOffset: Int = 0
    @StateObject var blurColors = BlurColors()
    
    @State private var genres: [PlexGenre] = []
    @State private var relatedCollections: [String: PlexHomeCollection] = [:]
    @State private var listRating: [PlexRating] = []
    
    @StateObject var viewModel = MovieDetailViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView() {
                
                VStack(alignment: .leading, spacing: 10) {
                    renderClearLogo
                    
                    VStack(alignment: .leading) {
                        // Rating Section
                        HStack {
                            
                            renderRating
                        }
                        
                        Text(metadata.type == "episode" ? ( metadata.grandParentTitle ?? metadata.title ) : metadata.title)
                            .font(.system(size: 24))
                            .bold()
                            .multilineTextAlignment(.leading)
                            .padding(.top, -5)
                            .padding(.vertical, 10)
                        
                        if let date = originallyAvailableAtDate,
                           date > Date() {
                            Text("Ra mắt ngày \(date.toDMYString())")
                                .font(.system(size: 14))
                                .bold()
                                .foregroundColor(Color("VArtThemeColor"))
                                .padding(.bottom, 10)
                        }
                        
                        // Content Rating Section
                        HStack {
                            if has4KVersion == true {
                                Text("4K")
                                    .font(.system(size: 20, weight: .black))
                                    .italic()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.yellow, Color.white, Color.yellow],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            
                            if let contentRating = metadata.contentRating {
                                Text(contentRating)
                                    .font(.system(size: 12))
                                    .bold()
                                    .foregroundColor(Color("GrayColor"))
                                    .frame(height: 20)
                                    .padding(.horizontal, 10)
                                    .background(.ultraThinMaterial)
                                    .environment(\.colorScheme, .light)
                                    .cornerRadius(20)
                            }
                            
                            if let year = metadata.year {
                                Text(year)
                                    .font(.system(size: 12))
                                    .bold()
                                    .foregroundColor(Color("GrayColor"))
                                    .frame(height: 20)
                                    .padding(.horizontal, 10)
                                    .background(.ultraThinMaterial)
                                    .environment(\.colorScheme, .light)
                                    .cornerRadius(20)
                            }
                            
                            if let duration = metadata.duration {
                                Text(formatDuration(duration))
                                    .font(.system(size: 12))
                                    .bold()
                                    .foregroundColor(Color("GrayColor"))
                                    .frame(height: 20)
                                    .padding(.horizontal, 10)
                                    .background(.ultraThinMaterial)
                                    .environment(\.colorScheme, .light)
                                    .cornerRadius(20)
                            }
                        }
                        
                        // Genres Section
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(genres.enumerated()), id: \.offset) { index, genre in
                                    let genre = genres[index]
                                    Text(genre.tag)
                                        .font(.system(size: 12))
                                        .bold()
                                        .foregroundColor(Color("GrayColor"))
                                        .onTapGesture {
                                            if let genreId = genre.id {
                                                navManager.push(
                                                    .collection(
                                                        sectionTitle: genre.tag,
                                                        hubKey: "/library/all?sort=addedAt:desc&genre=\(genreId)",
                                                        isDiscover: false,
                                                        hasFilteredHeader: true
                                                    )
                                                )
                                                
                                            }
                                        }
                                    if index != genres.count - 1 {
                                        Circle()
                                            .fill(Color("VArtThemeColor"))
                                            .frame(width: 5, height: 5)
                                            .shadow(color: Color("VArtThemeColor"), radius: 6, x: 0, y: 0)
                                    }
                                }
                                
                            }
                        }
                        .padding(.top, 5)
                        
                        // Button Section
                        VStack(alignment: .center, spacing: 15) {
                            HStack(alignment: .center, spacing: 10) {
                                if !isDiscover {
                                    Button(action: {
                                        if let selectedData = viewModel.selectedMetadata {
                                            playButtonTapped(versions: selectedData.listVersionFiltered)
                                        } else {
                                            
                                        }
                                    }) {
                                        HStack {
                                            if let selectedData = viewModel.selectedMetadata {
                                                Image(systemName: selectedData.viewOffset > 0 ? "memories" : "play.fill")
                                                    .foregroundColor(Color("ButtonText"))
                                                Text(
                                                    "\(selectedData.viewOffset > 0 ? "Tiếp Tục Xem" : "Xem Từ Đầu")\(selectedData.type == "episode" ? " M\(selectedData.seasonIndex ?? 1)•T\(selectedData.episodeIndex ?? 1)" : "")"
                                                ).fontWeight(.semibold)
                                                    .foregroundColor(Color("ButtonText"))
                                                
                                            } else {
                                                ProgressView()
                                                    .frame(width: 200)
                                            }
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .frame(height: 50)
                                        .background(Color("VArtThemeColor"))
                                        .cornerRadius(30)
                                    }
                                    .buttonStyle(.plain)
                                    // .padding(.top, 25)
                                    // .padding(.horizontal, 50)
                                }
                                
                                
                                Button(action: {
                                    toggleWatchlist(ratingKey: currentPlexRatingKey)
                                }) {
                                    HStack {
                                        if !isLoadingWatchlisted {
                                            Image(systemName: isWatchlisted ? "heart.fill" : "heart")
                                                .foregroundColor(Color("AccentColor"))
                                                .clipShape(Circle())
                                            if isDiscover {
                                                Text(
                                                    "\(isWatchlisted ? "Xoá Khỏi Watchlist" : "Thêm Vào Watchlist")"
                                                )
                                                .fontWeight(.semibold)
                                                .foregroundColor(Color("AccentColor"))
                                            }
                                        } else {
                                            ProgressView()
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .font(.headline)
    //                                    .padding(.horizontal, 20)
    //                                    .padding(.vertical, 12)
                                    .frame(width: isDiscover ? 220 : 50, height: 50)
                                    .background {
                                        if #available(tvOS 26.0, *),
                                           #available(iOS 26.0, *) {
                                            Rectangle()
                                                .foregroundStyle(.clear)
                                                .glassEffect(.clear)
                                        } else {
                                            Color.gray.opacity(0.2)
                                        }
                                    }
                                    .cornerRadius(30)
                                }
                                .buttonStyle(.plain)
                            
                            }
                            
                            HStack(alignment: .top, spacing: 10) {
                                Button(action: {
                                    if let selectedMetadata = viewModel.selectedMetadata {
                                        viewModel.toggeWatchState(id: selectedMetadata.id, isMarkAsUnwatch: viewModel.isWatched)
                                        // viewModel.isWatched.toggle()
                                        shouldReloadSeason = true
                                        // DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            Task {
                                                await viewModel.fetchMetadataDetailAsync(id: metadata.grandParentId ?? metadata.parentId ?? metadata.id)
                                            }
                                        // }
                                    }
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: viewModel.isWatched ? "checkmark.circle.fill" : "checkmark.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(Color("AccentColor"))
                                            .padding(12)
                                            .background {
                                                if #available(tvOS 26.0, *),
                                                   #available(iOS 26.0, *) {
                                                    Rectangle()
                                                        .foregroundStyle(.clear)
                                                        .glassEffect(.clear)
                                                } else {
                                                    Color.gray.opacity(0.2)
                                                }
                                            }
                                            .clipShape(Circle())
                                        
                                        Text("Đánh dấu \(viewModel.isWatched ? "chưa xem" : "đã xem")")
                                            .font(.caption)
                                            .foregroundColor(Color.white.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .frame(width: isIpad ? 70 : 60, alignment: .center)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isIpad ? .leading : .center)
                        .padding(.vertical, 20)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)
                    
//                    if isDiscover {
//                        LocationSelectorSectionView(sectionTitle: "Xem Ở Đây Nè", metadatas: listLocation)
//                    }
                    
                    Text(viewModel.metaDataDetail?.summary ?? "")
                        .foregroundColor(.white)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 3)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                        .onTapGesture {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        }
                    
                    if !listDirector.isEmpty {
                        HStack(spacing: 5) {
                            Text("Đạo diễn bởi")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(Array(listDirector.enumerated()), id: \.1.id) { index, director in
                                        Text("\(director.tag)\(index != listDirector.count - 1 ? "," : "")")
                                            .onTapGesture {
                                                navManager.push(.actorDetail(actor: director))
                                            }
                                    }
                                }
                            }
                        }
                        .foregroundColor(Color("AccentColor"))
                        .font(.system(size: 15))
                        .layoutPriority(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .fontWeight(.semibold)
                    }
                    
                    if let firstVideoVersion = viewModel.selectedMetadata?.listVersion.first {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Text("Chất lượng")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 100, alignment: .leading)
                                Text("\(firstVideoVersion.videoResolution == "4k" ? "4K" : "\(firstVideoVersion.videoResolution)p") (\(formatVideoCodec(firstVideoVersion.videoCodec)))")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 10) {
                                Text("Âm thanh")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 100, alignment: .leading)
                                Text(viewModel.selectedAudio?.extendedDisplayTitle ?? "Không có")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 10) {
                                Text("Phụ đề")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 100, alignment: .leading)
                                if let subtitle = viewModel.selectedSubtitle {
                                    Text("\(subtitle.extendedDisplayTitle)")
                                        .font(.subheadline)
                                        .foregroundColor(Color("AccentColor"))
                                } else {
                                    Text("Không có")
                                        .font(.subheadline)
                                        .foregroundColor(Color("AccentColor"))
                                }
                            }
                        }
                        .padding(.top, 25)
                        .padding(.horizontal)
                    }
                    
                }
                
                // Actors and Related Sections
//                VStack(alignment: .leading, spacing: 10) {
//                    if metadata.type == "show" || metadata.type == "episode" {
//                        SeasonSelectorView(
//                            id: metadata.grandParentId ?? metadata.parentId ?? metadata.id,
//                            isDiscover: isDiscover,
//                            movieDetailViewModel: viewModel,
//                            onSelectEpisode: { episode in
//                                Task {
//                                    await viewModel.updateSelectedMetadataByEpisode(episodeData: episode)
//                                }
//                                
//                            },
//                            triggerReload: $shouldReloadSeason
//                        )
//                        .id(metadata.grandParentId ?? metadata.parentId ?? metadata.id)
//                    }
//                    
//                    if !listRole.isEmpty {
//                        ActorSectionView(sectionTitle: "Diễn Viên & Đoàn Phim", roles: listRole)
//                    }
//                }
                
                
                
                if relatedCollections.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack {
                        ForEach(Array(relatedCollections.values), id: \.title) { collection in
                            SectionView(
                                sectionTitle: replaceTitle(title: collection.title),
                                hubKey: collection.key,
                                metadatas: collection.metadatas ?? [],
                                isLandscapeSection: collection.id == "extras" ? true : false,
                                isDiscover: isDiscover
                            )
                        }
                    }
                    
                    
                }
                
                Spacer(minLength: 100)
            }
            
            versionPopupView
            
        } // main zstack
        .background {
            backgroundView
        }
        // .id(reloadID)
        .ignoresSafeArea(edges: .all)
        
        .onAppear {
            if !isDiscover {
                Task {
                    if let guid = metadata.guid {
                        if let metadataDiscoverDetail = await viewModel.fetchMetadataFromDiscoverAsync(id: viewModel.extractRatingKey(from: guid) ?? "") {
                            DispatchQueue.main.async {
                                renderDiscoverImage(metadataDetail: metadataDiscoverDetail)
                            }
                        }
                        
                    }
                }
            }
            
            viewModel.fetchThumbnail(url: metadata.thumbnail)
            
            if let plexBlurColors = metadata.ultraBlurColors {
                blurColors.topLeft = plexBlurColors.topLeft
                blurColors.topRight = plexBlurColors.topRight
                blurColors.bottomLeft = plexBlurColors.bottomLeft
                blurColors.bottomRight = plexBlurColors.bottomRight
                
                print("topLeft: \(blurColors.topLeft) - topRight: \(blurColors.topRight) - bottomLeft: \(blurColors.bottomLeft) - bottomRight: \(blurColors.bottomRight)")
            }
            
//            if let plexGenres = metadata.genres {
//                genres = plexGenres
//            }
            
            
            Task {
                await viewModel.fetchMetadataDetailAsync(id: metadata.grandParentId ?? metadata.parentId ?? metadata.id, isDiscover: isDiscover)
                
                if let guid = viewModel.metaDataDetail?.guid {
                    currentPlexRatingKey = viewModel.extractRatingKey(from: guid) ?? ""
                    isLoadingWatchlisted = true
                    viewModel.fetchUserState(ratingKey: currentPlexRatingKey) { userState in
                        isWatchlisted = userState.watchlistedAt != nil ? true : false
                        isLoadingWatchlisted = false
                    }
                }
                
                if let selectedMetadata = viewModel.selectedMetadata {
                    
                    self.has4KVersion = selectedMetadata.listVersion.first {
                        $0.videoResolution == "4k"
                    } != nil
                }
                
                if let roles = viewModel.metaDataDetail?.roles {
                    listRole = roles
                }
                
                if let directors = viewModel.metaDataDetail?.directors {
                    listDirector = directors
                    listRole.append(contentsOf: listDirector)
                }
                
                if let ratings = viewModel.metaDataDetail?.rating {
                    listRating = ratings
                }
                
                if let plexGenres = viewModel.metaDataDetail?.genres {
                    genres = plexGenres
                }
                
                if let releaseDate = viewModel.metaDataDetail?.originallyAvailableAt {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    originallyAvailableAtDate = formatter.date(from: releaseDate)
                }
                
                if let extras = viewModel.metaDataDetail?.extras {
                    listTrailer = extras.metadatas[0].medias
                    if !listTrailer.isEmpty {
                        let trailerSd = listTrailer.first {
                            $0.videoResolution == "sd"
                        }
                        
                        if let checkedTrailerSd = trailerSd {
                            if !checkedTrailerSd.parts.isEmpty {
                                videoTrailerUrl = PlexAPI.shared.getDiscoverVideoUrl(urlString: checkedTrailerSd.parts[0].url)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showVideo = true
                                        isReadyToPlayVideo = true
                                    }
                                }
                            }
                        }
                        
                        
                    }
                }
                
                themeMusicUrl = PlexAPI.shared.getPosterURL(url: viewModel.metaDataDetail?.themeSong)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        playMusic = true
                    }
                }
                
                if isDiscover {
                    if let metadataDetailDiscover = viewModel.metaDataDetail {
                        
                        if metadata.ultraBlurColors == nil {
                            if let plexBlurColors = metadataDetailDiscover.ultraBlurColors {
                                blurColors.topLeft = plexBlurColors.topLeft
                                blurColors.topRight = plexBlurColors.topRight
                                blurColors.bottomLeft = plexBlurColors.bottomLeft
                                blurColors.bottomRight = plexBlurColors.bottomRight
                            }
                        }
                        
                        
                        renderDiscoverImage(metadataDetail: metadataDetailDiscover)
                    }
                    viewModel.fetchWatchFromTheseLocation(guid: viewModel.metaDataDetail?.guid ?? "") { locations in
                        // print("locations: \(locations)")
                        listLocation = locations
                        
                    }
                }
            }
            
            if hasFetchedRelated == false {
                hasFetchedRelated = true
                
                viewModel.fetchRelatedByRatingKey(ratingKey: metadata.grandParentId ?? metadata.parentId ?? metadata.id, isDiscover: isDiscover){ collections in
                    // print("collections: \(collections)")
                    for collection in collections {
                        relatedCollections[collection.id] = collection
                        viewModel.fetchMetadatasByHubKey(key: collection.key, offset: collection.metadatas?.count ?? 0, size: 36, isDiscover: isDiscover){ metadatas in
                            if var existingCollection = relatedCollections[collection.id]?.metadatas {
                                existingCollection.append(contentsOf: metadatas)
                                relatedCollections[collection.id]?.metadatas = existingCollection
                            } else {
                                relatedCollections[collection.id]?.metadatas = metadatas
                            }
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDidDismiss)) { _ in
            if !isDiscover {
                // fetch metadata detail again to update watch state
                Task {
                    await self.viewModel.fetchMetadataDetailAsync(id: metadata.grandParentId ?? metadata.parentId ?? metadata.id, isDiscover: isDiscover)
                }
            }
        }
        .zIndex(1)
        .animation(.easeInOut, value: showVersionPopup)
    }// body
    
    func formatBirate(_ number: Double, decimalPlaces: Int = 1) -> String {
        String(format: "%.\(decimalPlaces)f", number / 1000)
    }
    
    private func playButtonTapped(versions: [PlexMedia]) {
        if versions.count == 1 {
            let firstVersion = versions[0]
            playVersion(version: firstVersion)
        } else {
            showVersionPopup = true
        }
    }
    
    private func showVideoPlayerLandscape(version: PlexMedia, dataPart: PlexMediaPart) {
        
        if let selectedMetadata = viewModel.selectedMetadata {
            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController else {
                    return
            }
            
            var queues: [QueueItem] = []
            var currentIndex = 0
            if selectedMetadata.type == "episode" {
                if let episodes = viewModel.episodes {
                    if let index = episodes.firstIndex(where: { $0.id == selectedMetadata.id }) {
                        print("Index is \(index)")
                        currentIndex = index
                        
                        for i in currentIndex...currentIndex + 20 {// max 21 queues from current index
                            if i < episodes.count {
                                let episodeByIndex = episodes[i]
                                queues.append(QueueItem(
                                    title: "M\(episodeByIndex.seasonIndex)•T\(episodeByIndex.episodeIndex) - \(episodeByIndex.title)",
                                    grandTitle: episodeByIndex.grandTitle,
                                    queueIndex: i - currentIndex,
                                    thumbnailUrl: episodeByIndex.thumbnailURL?.absoluteString ?? "",
                                    ratingKey: episodeByIndex.id,
                                    duration: episodeByIndex.duration
                                ))
                            }
                        }
                    }
                    
                }
                
            } else {
                queues.append(QueueItem(
                    title: metadata.title,
                    grandTitle: metadata.grandParentTitle ?? metadata.title,
                    queueIndex: 1,
                    thumbnailUrl: viewModel.localThumbnailURL?.absoluteString ?? "",
                    ratingKey: selectedMetadata.id,
                    duration: selectedMetadata.duration
                ))
            }
            
            
            let playbackData = PlaybackData(
                videoUrl: dataPart.url,
                videoTitle: selectedMetadata.type == "episode" ? "\(metadata.grandParentTitle ?? metadata.title) - M\(selectedMetadata.seasonIndex ?? 1)•T\(selectedMetadata.episodeIndex ?? 1)" : metadata.title,
                grandVideoTitle: metadata.title,
                viewOffset: selectedMetadata.viewOffset,
                duration: selectedMetadata.duration,
                videoID: dataPart.id,
                grandVideoID: dataPart.id,
                ratingKey: selectedMetadata.id,
                thumbnailUrl: viewModel.localThumbnailURL?.absoluteString ?? "",
                mediaPartStreams: dataPart.streams,
                currentIndex: 0,
                playlist: queues,
                ultraBlurColors: metadata.ultraBlurColors ?? PlexUltraBlurColors(
                    topLeft: "#000000",
                    topRight: "#000000",
                    bottomRight: "#000000",
                    bottomLeft: "#000000"
                ),
                markers: selectedMetadata.listMarker,
                versions: selectedMetadata.listVersionFiltered,
                selectedMediaId: version.id
            )
        }
        
    }
    
    func playVersion(version: PlexMedia) {
        let versionPart = version.parts[0]
        selectedVersionPart = versionPart
        showVersionPopup = false
        
        if let dataPart = selectedVersionPart {
            showVideoPlayerLandscape(version: version, dataPart: dataPart)
        }
    }
    
    func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 || hours == 0 {
            components.append("\(minutes)m")
        }
        return components.joined(separator: " ")
    }
    
    func toggleWatchlist(ratingKey: String) {
        if isWatchlisted {
            viewModel.removeFromWatchlist(ratingKey: ratingKey)
        } else {
            viewModel.addToWatchlist(ratingKey: ratingKey)
        }
        isWatchlisted = !isWatchlisted
    }
    
    func replaceTitle(title: String) -> String {
        var result = title
            
        let replacements: [String: String] = [
            "Collection": "",
            "More with": "Phim của",
            "More by": "Phim của",
            "Related Movies": "Phim có liên quan",
            "Related Shows": "Series có liên quan",
            "TV Shows in": "",
            "Movies in": "",
            "More from": "Có trên",
        ]
        
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: key, with: value)
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func renderDiscoverImage(metadataDetail: PlexMetaDataDetail) {
        if let images = metadataDetail.images {
            let backgroundSquare = images.first {
                $0.type == "backgroundSquare"
            }
//
            if let checkBackgroundSquare = backgroundSquare, !isIpad {
                DispatchQueue.main.async {
                    viewModel.thumbnailURL = URL(string: checkBackgroundSquare.url)
                }
            } else {
                let background = images.first {
                    $0.type == "background"
                }
                if let checkBackground = background {
                    DispatchQueue.main.async {
                        viewModel.thumbnailURL = URL(string: checkBackground.url)
                    }
                } else {
                    viewModel.thumbnailURL = viewModel.localThumbnailURL
                }
            }
            
            let clearLogo = images.first {
                $0.type == "clearLogo"
            }
            
            if let checkClearLogo = clearLogo {
                DispatchQueue.main.async {
                    viewModel.logoURL = URL(string: checkClearLogo.url)
                }
            }
        }
    }
    
    @ViewBuilder
    var backgroundView: some View {
        GeometryReader { geometry in
            // if let plexBlurColors = metadata.ultraBlurColors {
                let width = geometry.size.width
                let height = geometry.size.height
                let radius = max(width, height)
                ZStack(alignment: .topLeading) {
                   
                    ZStack(alignment: .topLeading) {
                        
                        
                        // Base background layer (black)
//                        Color(hex: "#3f4245")
//                            .ignoresSafeArea()
                        Color.black
                        
                        let bottomLeftColor = Color(hex: blurColors.bottomLeft)
                        // Bottom Left (0% 100%)
                        RadialGradient(
                            gradient: Gradient(colors: [
                                bottomLeftColor,
                                bottomLeftColor.opacity(0)
                            ]),
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: radius
                        )

                        let bottomRightColor = Color(hex: blurColors.bottomRight)
                        // Bottom Right (100% 100%)
                        RadialGradient(
                            gradient: Gradient(colors: [
                                bottomRightColor,
                                bottomRightColor.opacity(0)
                            ]),
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: radius
                        )

                        let topRightColor = Color(hex: blurColors.topRight)
                        // Top Right (100% 0%)
                        RadialGradient(
                            gradient: Gradient(colors: [
                                topRightColor,
                                topRightColor.opacity(0)
                            ]),
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: radius
                        )
                        
                        let topLeftColor = Color(hex: blurColors.topLeft)
                        // Top Left (0% 0%)
                        RadialGradient(
                            gradient: Gradient(colors: [
                                topLeftColor,
                                topLeftColor.opacity(0)
                            ]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: radius
                        )
                    }
                    .background(.clear)
                    .frame(width: width, height: height, alignment: .topLeading)
                    
                    .offset(x: 0, y: 0)
                    
                    renderThumbnailWithVideoPad
                }
                .frame(width: width, height: height, alignment: .topLeading)
        }
        
    }

    @ViewBuilder
    var renderClearLogo: some View {
        ZStack {
            WebImage(url: viewModel.logoURL, options: [.scaleDownLargeImages]) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: isIpad ? 100 : thumnailHeight, alignment: isIpad ? .bottomLeading : .bottom)
                    .padding(.horizontal, isIpad ? 0 : 30)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .foregroundColor(Color(red: 0.15, green: 0.17, blue: 0.2))
                    .opacity(0)
                    .frame(width: 250, height: isIpad ? 150 : thumnailHeight)
            }
            .cancelOnDisappear(true)
            .indicator(.activity)
            .transition(.fade(duration: 0.5))
            .padding(.bottom, -15)
            .frame(maxWidth: .infinity, maxHeight: thumnailHeight, alignment: isIpad ? .bottomLeading : .center)
            .frame(height: isIpad ? 150 : thumnailHeight)
            .offset(
                x: isIpad ? 15 : 0,
            )
        }
        
    }
    
    @ViewBuilder
    var renderRating: some View {
        if listRating.isEmpty {
            ForEach(0..<2) { _ in
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                    
                    Text("–.–")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .fontWeight(.bold)
                }
            }
        } else {
            ForEach(listRating) { rating in
                HStack(spacing: 5) {
                    Image(rating.mappedImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 20)
                    Text(rating.normalizedValue)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    @ViewBuilder
    var renderThumbnailOnly: some View {
        WebImage(url: viewModel.thumbnailURL, options: [.scaleDownLargeImages]) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: gemetrySizeWidth, height: scrollOffset > 0 ? thumnailHeight + scrollOffset : thumnailHeight)
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
                //.clipped()
                .offset(
                    y: scrollOffset > 0 ? 0 : (
                        scrollOffset < -trigger
                            ? (scrollOffset + trigger) * 0.5
                            : 0
                    )
                )
                // .scaleEffect(scrollOffset > 0 ? 1 + (scrollOffset / 300) : 1)
                .opacity(1 - min(1, max(0, (-scrollOffset) / 300)))
                .allowsHitTesting(false)
        } placeholder: {
            Color.clear.frame(width: gemetrySizeWidth, height: thumnailHeight)
        }
        .cancelOnDisappear(true)
        .indicator(.activity)
        .transition(.fade(duration: 0.5))
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 200 / thumnailHeight),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(
                y: scrollOffset > 0 ? 0 : (
                scrollOffset < -trigger
                    ? (scrollOffset + trigger) * 0.5
                    : 0)
            )
        )
    }
    
    @ViewBuilder
    var videoGradientMask: some View {
        if isIpad {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 100 / thumnailHeight),
                    .init(color: .white, location: 300 / thumnailHeight),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
                    
            )
            .mask(
                LinearGradient(
                    gradient:
                        Gradient(colors: [
                            .clear,
                            .white,
                            .white,
                            .clear,
                        ]),
                        startPoint: .leading, endPoint: .trailing
                )
            )
            .offset(
                y: scrollOffset > 0 ? 0 : (
                scrollOffset < -trigger
                    ? (scrollOffset + trigger) * 0.5
                    : 0)
            )
        } else {
            
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 100 / thumnailHeight),
                    .init(color: .white, location: 300 / thumnailHeight),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(
                y: scrollOffset > 0 ? 0 : (
                    scrollOffset < -trigger
                        ? (scrollOffset + trigger) * 0.5
                        : 0)
            )
        }
    }
    
    func formatVideoCodec(_ codec: String) -> String {
        switch codec.lowercased() {
        case "h264":
            return "H.264"
        case "hevc":
            return "HEVC"
        case "mpeg4":
            return "MPEG-4"
        case "vp9":
            return "VP9"
        case "av1":
            return "AV1"
        default:
            return codec.uppercased()
        }
    }
    
    @ViewBuilder
    var versionPopupView: some View {
        if showVersionPopup {
            
            Color.black.opacity(0.4)
                .transition(.opacity)
                .ignoresSafeArea()
            ZStack {

                VStack(spacing: 20) {
                    Text("Chọn phiên bản phát")
                        .foregroundColor(.white)
                        .font(.headline)

                    ScrollView {
                        VStack(spacing: 10) {
                            if let selectedMetadata = viewModel.selectedMetadata {
                                ForEach(selectedMetadata.listVersionFiltered, id: \.id) { version in
                                    Button(action: {
                                        playVersion(version: version)
                                    }) {
                                        HStack {
                                            Text("\((version.videoResolution == "4k" || version.videoResolution == "sd") ? version.videoResolution : "\(version.videoResolution)p"), \(formatBirate(Double(version.bitrate ?? 0))) Mbps")
                                                .bold()
                                                .foregroundColor(Color("VArtThemeColor"))
                                            
                                            if version.parts[0].accessible {
                                            } else {
                                                Text("Unavailable")
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 14)
                                                    .background(Color.red.opacity(0.85))
                                                    .clipShape(Capsule())
                                                
                                            }
                                            
                                        }
                                        .padding()
                                        .background(Color.clear)
                                    }
                                }
                            }
                            
                        }
                    }
                    .frame(maxHeight: 250)

                    Button("Huỷ") {
                        showVersionPopup = false
                    }
                    .foregroundColor(.white)
                }
                .padding()
                .frame(width: 300)
                .background(Color("BackgroundColor"))
                .cornerRadius(20)
                .shadow(radius: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.scale)
            
        }
    }
    
    @ViewBuilder
    var renderThumbnailWithVideoPad: some View {
        ZStack {
//            if showVideo {
//                videoTrailerView
//            } else {
                let thumbnailWidth = gemetrySizeWidth * 0.6
                WebImage(url: viewModel.thumbnailURL, options: [.scaleDownLargeImages]) { image in
                    image
                        .scaledToFill()
                        .frame(width: thumbnailWidth,
                               height: scrollOffset > 0 ? thumnailHeight + scrollOffset : thumnailHeight)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(contentMode: .fit)
                        .offset(y: scrollOffset > 0 ? 0 : (
                            scrollOffset < -trigger
                                ? (scrollOffset + trigger) * 0.5
                                : 0))
                        .opacity(1 - min(1, max(0, (-scrollOffset) / 300)))
                        .allowsHitTesting(false)
                } placeholder: {
                    Color.clear.frame(width: thumbnailWidth, height: thumnailHeight)
                }
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.5))
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 300 / thumnailHeight),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                            
                    )
                    .mask(
                        LinearGradient(
                            gradient:
                                Gradient(colors: [
                                    .clear,
                                    .white,
                                    .white]),
                                startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .offset(
                        y: scrollOffset > 0 ? 0 : (
                        scrollOffset < -trigger
                            ? (scrollOffset + trigger) * 0.5
                            : 0)
                    )
                        
                )
                .onAppear {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                        withAnimation(.easeInOut(duration: 0.4)) {
//                            print("show video")
//                            showVideo = true
//                        }
//                    }
                }
            // }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
