//
//  VideoPlayerView.swift
//  bLoopTV
//
//  Created by Monster on 21/1/26.
//

import SwiftUI
import SDWebImageSwiftUI

enum ControlFocus {
    case slider
}

struct PlayerGestures {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onPressLeft: () -> Void
    var onPressRight: () -> Void
    var onPressDown: () -> Void
    var onPlayPause: () -> Void
    var onTouch: () -> Void
    var onExit: () -> Void
}

struct VideoPlayerView: View {
    enum PlayerFocusField {
        case gestureLayer
        case mediaSettings
    }
    
    @EnvironmentObject var navManager: NavigationPathManager

    let playbackData: PlaybackData
    var onDismiss: (() -> Void)?

    // Mỗi lần vào player 1 coordinator + controller + mpv context riêng, destroy khi thoát (ổn định, không
    // bị video chồng nhau/lag khi chuyển qua lại nhiều video).
    @ObservedObject var coordinator = MPVMetalPlayerView.Coordinator()
    @FocusState private var isPanelFocused: Bool
    @FocusState private var focusedElement: SeekBarView.FocusField?
    
    @FocusState private var focusedField: PlayerFocusField?

    @State private var loading = false
    @State private var showControls = true
    @State private var position: Double = 0
    @State private var isSeeking = false
    @State private var showMediaSettings = false
    @State private var selectedAudioId: Int? = -1
    @State private var selectedSubtitleId: Int? = -1
    @State private var progressTimer: Timer? = nil
    @State private var hideControlsWork: DispatchWorkItem? = nil
    @State private var bufferProgress: Double = 0

    // Track nhúng sẵn trong file (audio/subtitle) mà metadata truyền vào không biết trước — bổ sung động
    // sau khi mpv tự dò ra, để MediaSettingsPanel hiển thị được (playbackData.mediaPartStreams là dữ liệu
    // tĩnh không tự cập nhật).
    @State private var mediaPartStreams: [PlexMediaPartStream] = []


    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    // Che player bằng thumbnail + spinner khi đang load video MỚI (khung mpv lúc này còn đen/rác) — ẩn đi
    // khi video bắt đầu phát thật. Resume (cùng video còn buffer) thì không cần che vì frame có sẵn ngay.
    @State private var showCover = true

    // Stremio không biết trước duration (playbackData.duration = 0 lần đầu xem) — lấy trực tiếp từ mpv
    // khi phát để seekbar không bị đứng ở 0. Với Plex đã có duration sẵn nên giá trị này không cần override.
    @State private var liveDurationMs: Int?

    private var effectiveDurationMs: Int {
        liveDurationMs ?? playbackData.duration
    }


    var body: some View {
        ZStack {
            
            // MARK: - Player
            MPVMetalPlayerView(coordinator: coordinator)
                .play(URL(string: playbackData.videoUrl)!)
                .onPropertyChange { player, propertyName, propertyData in
                    switch propertyName {
                    case MPVProperty.playing:
                        startSeekTimer()
                        hideCover()
                    case MPVProperty.pausedForCache:
                        let buffering = propertyData as? Bool ?? false
                        loading = buffering
                        // Hết buffering lần đầu = frame đã sẵn sàng hiển thị → bỏ lớp che.
                        if !buffering { hideCover() }
                    case MPVProperty.timePos:
                        if !isSeeking {
                            position = propertyData as? Double ?? 0
                            // Check for Intro Markers
                            checkIntroStatus(currentPos: position)
                        }
                    default:
                        break
                    }
                }
            
            ZStack {
                // MARK: - Bottom Gradient (VidHub style)
                VStack {
                    Spacer()
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.0)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                
                // MARK: - SeekBar
                VStack {
                    Spacer()
                    SeekBarView(
                        position: $position,
                        bufferProgress: $bufferProgress,
                        duration: Double(effectiveDurationMs / 1000),
                        showSkipIntro: coordinator.showSkipIntro,
                        introEndMs: coordinator.introEndMs,
                        isScrubbing: isScrubbing,
                        scrubPosition: $scrubPosition,
                        focusedElement: $focusedElement,
                        onSeek: { newPosition in
                            coordinator.player?.seekToSeconds(seconds: newPosition)
                        },
                        onSkipIntro: { skipToSeconds in
                            coordinator.player?.seekToSeconds(seconds: skipToSeconds)
                            coordinator.showSkipIntro = false
                        },
                        gestures: PlayerGestures(
                            onSwipeLeft: { showTemporarily() },
                            onSwipeRight: { showTemporarily() },
                            onSwipeUp: {
                                showTemporarily()
                                if coordinator.showSkipIntro { focusedElement = .skipButton }
                            },
                            onSwipeDown: {
                                showTemporarily()
                                if !showMediaSettings {
                                    withAnimation(.spring()) { showMediaSettings = true }
                                }
                            },
                            onPressLeft: { seek(by: -10) },
                            onPressRight: { seek(by: 10) },
                            onPressDown: { showTemporarily() },
                            onPlayPause: { coordinator.player?.togglePause() },
                            onTouch: { showTemporarily() },
                            onExit: {  }
                        )
                    )
                }
            }
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: showControls)
            
            
            // MARK: - Media Settings Panel
//            if showMediaSettings {
//                MediaSettingsPanel(
//                    isPresented: $showMediaSettings,
//                    selectedAudioId: $selectedAudioId,
//                    selectedSubtitleId: $selectedSubtitleId,
//                    streams: playbackData.mediaPartStreams,
//                    onSelectAudio: { track in
//                        coordinator.player?.selectAudioTrack(audioTrack: track)
//                    },
//                    onSelectSubtitle: { track in
//                        if let selectedTrack = track {
//                            coordinator.player?.selectSubtitle(subtitleTrack: selectedTrack)
//                            
//                        }
//                    }
//                )
//                .focused($focusedField, equals: .mediaSettings)
//                .animation(
//                    .spring(response: 0.35, dampingFraction: 0.85),
//                    value: showMediaSettings
//                )
//                .zIndex(10)
//                .onMoveCommand { direction in
//                    //                    if direction == .up {
//                    //                        if showMediaSettings {
//                    //                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                    //                                showMediaSettings = false
//                    //                            }
//                    //                            showControls = false
//                    //                        }
//                    //                    }
//                }
//                .onExitCommand {
//                    triggerExitComand()
//                }
//                
//            }
            
            TVGestureView(
                isScrubbing: { isScrubbing },
                onSwipeLeft:  {
                    showTemporarily()
                },
                onSwipeRight:  {
                    showTemporarily()
                },
                onSwipeUp:  {
                    showTemporarily()
                    if showMediaSettings {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMediaSettings = false
                        }
                    }
                    
                    // If Skip Intro is active, snap focus to it immediately
                    if coordinator.showSkipIntro {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedElement = .skipButton
                        }
                    } else {
                        // Otherwise, focus the seekbar
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedElement = .seekbar
                        }
                    }
                },
                onSwipeDown: {
                    showTemporarily()
                    if !showMediaSettings {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showMediaSettings = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPanelFocused = true
                        }
                    }
                },
                onPressLeft: {
                    showTemporarily()
                    if !showMediaSettings && !isScrubbing {
                        seek(by: -10)
                    }
                },
                onPressRight:  {
                    showTemporarily()
                    if !showMediaSettings && !isScrubbing {
                        seek(by: 10)
                    }
                },
                onPressDown:  {
                    showTemporarily()
                },
                onPlayPause: {
                    showTemporarily()
                    coordinator.player?.togglePause()
                },
                onTouch: {
                    showTemporarily()
                },
                onExit: {
                    onDismiss?()
                    return
                },
                onMenuPress: {
                    if isScrubbing {
                        coordinator.player?.play()
                        coordinator.player?.seekToSeconds(seconds: scrubPosition)
                        position = scrubPosition
                        withAnimation(.spring()) { isScrubbing = false }
                        showTemporarily()
                    } else {
                        coordinator.player?.pause()
                        scrubPosition = position
                        withAnimation(.spring()) {
                            isScrubbing = true
                            
                            showTemporarily()
                        }
                        hideControlsWork?.cancel()
                    }
                    
                },
                onScrubChanged: { delta in
                    guard isScrubbing else { return }
                    let totalDuration = Double(effectiveDurationMs / 1000)
                    let step = Double(delta) * totalDuration
                    scrubPosition = min(max(scrubPosition + step, 0), totalDuration)
                },
                onScrubEnded: { }
            )
            .focused($focusedField, equals: .gestureLayer)
            .zIndex(2)
            .allowsHitTesting(true)
            .onExitCommand {
                triggerExitComand()
            }

            // MARK: - Loading Cover (player dưới cùng → thumbnail giữa → spinner trên cùng)
            if showCover {
                ZStack {
                    Color.black

                    WebImage(url: URL(string: playbackData.thumbnailUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    OrangeSpinner()
                        .frame(width: 60, height: 60)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(3)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            isPanelFocused = true
            focusedField = .gestureLayer

            // Gắn closure TRƯỚC khi phát để không lỡ sự kiện "playing" khi resume (play() có thể fire ngay).
            coordinator.player?.onPlaybackStateChange = { state in
                switch state {
                case "playing":
                    startSeekTimer()
                    hideCover()
                default:
                    break
                }
            }

            coordinator.player?.onTracksDiscovered = { newTracks in
                mediaPartStreams.append(contentsOf: newTracks)

                if selectedAudioId == -1, let defaultAudio = newTracks.first(where: { $0.streamType == 2 && $0.selected == true }) {
                    selectedAudioId = defaultAudio.id
                }
                if selectedSubtitleId == -1, let defaultSubtitle = newTracks.first(where: { $0.streamType == 3 && $0.selected == true }) {
                    selectedSubtitleId = defaultSubtitle.id
                }
            }

            // Cùng video còn buffer → resume ngay, không load lại. Video mới/lần đầu → init đầy đủ.
            let resumed = coordinator.player?.loadOrResume(playbackData: playbackData) ?? false

            // Resume: frame có sẵn → không che. Load mới: che bằng thumbnail cho tới khi phát thật.
            showCover = !resumed

            if resumed {
                // Khôi phục lại state UI từ controller (view là instance mới nên state đã reset về mặc định).
                let audio = coordinator.player?.listAudioTrack ?? []
                let subs = coordinator.player?.listSubtitle ?? []
                mediaPartStreams = audio + subs
                selectedAudioId = coordinator.player?.selectedAudioId ?? -1
                selectedSubtitleId = coordinator.player?.selectedSubtitleId ?? -1
                // Đồng bộ lại seekbar về vị trí thật của mpv ngay (không đợi sự kiện "playing").
                startSeekTimer()
            } else {
                seek(by: Double(playbackData.viewOffset / 1000))
                mediaPartStreams = playbackData.mediaPartStreams

                let preferredLanguage = UserSelectionsService.shared.getPreferredAudioLanguageTag()

                selectedAudioId = playbackData.mediaPartStreams
                    .first { $0.streamType == 2 && preferredLanguage != nil && $0.languageTag == preferredLanguage }?.id
                    ?? playbackData.mediaPartStreams.first { $0.streamType == 2 && $0.selected == true }?.id
                    ?? -1

                let savedSubtitleId = UserSelectionsService.shared.getTrackSelection(for: playbackData.videoID ?? 0)?.subtitleID
                // Chưa từng chọn ngôn ngữ ưu tiên thì mặc định tiếng Việt.
                let preferredSubtitleLang = UserSelectionsService.shared.getPreferredSubtitleLanguageTag() ?? "vi"

                selectedSubtitleId = playbackData.mediaPartStreams
                    .first { $0.streamType == 3 && savedSubtitleId != nil && $0.id == savedSubtitleId }?.id
                    ?? playbackData.mediaPartStreams.first { $0.streamType == 3 && $0.languageTag == preferredSubtitleLang }?.id
                    ?? playbackData.mediaPartStreams.first { $0.streamType == 3 && $0.selected == true }?.id
                    ?? -1
            }

            showTemporarily()
        }
        .onChange(of: showMediaSettings) { newValue in
            focusedField = newValue ? .mediaSettings : .gestureLayer
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil

            // Gỡ closure trước khi destroy để không gọi lại state của view đã biến mất.
            coordinator.player?.onPlaybackStateChange = nil
            coordinator.player?.onTracksDiscovered = nil
            coordinator.onPropertyChange = nil

            // Giải phóng hẳn mpv context (guard chống double-destroy với dismantleUIViewController).
            coordinator.destroyPlayer()
        }
        .overlay {
            if showMediaSettings {
                MediaSettingsPanel(
                    isPresented: $showMediaSettings,
                    selectedAudioId: $selectedAudioId,
                    selectedSubtitleId: $selectedSubtitleId,
                    streams: mediaPartStreams,
                    onSelectAudio: { track in
                        coordinator.player?.selectAudioTrack(audioTrack: track)
                    },
                    onSelectSubtitle: { track in
                        if let selectedTrack = track {
                            coordinator.player?.selectSubtitle(subtitleTrack: selectedTrack)
                        } else {
                            coordinator.player?.disableSubtitle()
                        }
                    }
                ).onExitCommand {
                    triggerExitComand()
                }
                .focused($focusedField, equals: .mediaSettings)
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
                .zIndex(999)
            }
        }
        .ignoresSafeArea()
    }
    
    func triggerExitComand() {
        if isScrubbing {
            withAnimation(.spring()) {
                isScrubbing = false
                coordinator.player?.play()
            }
            showTemporarily()
        } else if showMediaSettings {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showMediaSettings = false
            }
            showControls = false
        } else if showControls {
            showControls = false
        } else {
            navManager.pop()
        }
    }

    // MARK: - Seek
    func seek(by seconds: Double) {
        let newPos = min(max(position + seconds, 0), Double(effectiveDurationMs / 1000))
        position = newPos
        coordinator.player?.command("seek", args: ["\(seconds)", "relative"])
        showTemporarily()
    }

    private func hideCover() {
        guard showCover else { return }
        withAnimation(.easeOut(duration: 0.4)) { showCover = false }
    }

    func showTemporarily() {
        showControls = true
        
        guard !isScrubbing else { return }
        
        hideControlsWork?.cancel()
        
        let work = DispatchWorkItem {
            showControls = false
        }
        hideControlsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    func formatTime(_ value: Double) -> String {
        guard value.isFinite else { return "00:00" }
        let total = Int(value)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
    
    private func checkIntroStatus(currentPos: Double) {
        let currentMs = Int(currentPos * 1000)
        if let markers = playbackData.markers {
            let intro = markers.first { $0.type == "intro" && currentMs >= $0.startTimeOffset && currentMs <= $0.endTimeOffset }
            
            DispatchQueue.main.async {
                if let foundIntro = intro {
                    coordinator.showSkipIntro = true
                    coordinator.introEndMs = foundIntro.endTimeOffset
                } else {
                    coordinator.showSkipIntro = false
                }
            }
        }
    }
    
    private func startSeekTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let player = coordinator.player else { return }
            guard !isSeeking else { return }

            let timePos = player.getTimePos()

            if liveDurationMs == nil || liveDurationMs == 0 {
                let mpvDurationSeconds = player.getDuration()
                if mpvDurationSeconds > 0 {
                    DispatchQueue.main.async {
                        liveDurationMs = Int(mpvDurationSeconds * 1000)
                    }
                }
            }

            let buffer = player.getBufferProgress(duration: effectiveDurationMs)

            DispatchQueue.main.async {
                position = timePos
                bufferProgress = buffer
                player.viewOffset = Int(timePos * 1000)

                checkIntroStatus(currentPos: timePos)
            }
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }
}

class TVGestureUIView: UIView, UIGestureRecognizerDelegate {
    var isScrubbing: (() -> Bool)?
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    var onSwipeUp: (() -> Void)?
    var onSwipeDown: (() -> Void)?
    var onPressLeft: (() -> Void)?
    var onPressRight: (() -> Void)?
    var onPressDown: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onTouch: (() -> Void)?
    var onExit: (() -> Void)?
    var onMenuPress: (() -> Void)?
    var onScrubChanged: ((CGFloat) -> Void)? // delta từ -1.0 đến 1.0
    var onScrubEnded: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        addGestureRecognizer(swipeRight)
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        addGestureRecognizer(swipeDown)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTouch))
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        tap.allowedPressTypes = []
        addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        pan.delegate = self
        addGestureRecognizer(pan)
        
        becomeFirstResponder()
    }
    
    override var canBecomeFocused: Bool {
        // Chỉ nhận focus khi không có bảng điều khiển nào khác đang hiện
        // Bạn có thể truyền một binding từ SwiftUI vào đây nếu muốn chính xác hơn
        return true
    }
    
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // Swipe handlers
    @objc func handleSwipeLeft()  { onSwipeLeft?() }
    @objc func handleSwipeRight() { onSwipeRight?() }
    @objc func handleSwipeUp()  { onSwipeUp?() }
    @objc func handleSwipeDown()  { onSwipeDown?() }
    @objc func handleTouch() { onTouch?() }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        
        guard isScrubbing?() == true else { return }
        
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .changed:
            let rawDelta = translation.x
            let vel = abs(velocity.x)
            
            let sensitivity: CGFloat
            switch vel {
            case 0..<300:
                sensitivity = 8000.0
            case 300..<800:
                sensitivity = 5000.0
            case 800..<1500:
                sensitivity = 3000.0
            default:
                sensitivity = 1500.0
            }

            let delta = min(max(rawDelta / sensitivity, -0.02), 0.02)
            onScrubChanged?(delta)
            gesture.setTranslation(.zero, in: self)
        case .ended:
            onScrubEnded?()
        default:
            break
        }
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.type {
            case .leftArrow:  onPressLeft?()
            case .rightArrow: onPressRight?()
            case .downArrow:  onPressDown?()
            case .playPause:  onPlayPause?()
            case .menu:
                
                blockMenuResponder = true

                onExit?()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    self.blockMenuResponder = false
//                }

                return // avoid exit
            default: break
            }
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return }

        if press.type == .menu {

            blockMenuResponder = true

            onExit?()

            
            return
        }

        if press.type == .select {
            onMenuPress?()
            return
        }

        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let filtered = presses.filter { $0.type != .menu }
        if !filtered.isEmpty {
            super.pressesCancelled(filtered, with: event)
        }
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }
    
    private var blockMenuResponder = false
}

/// Bọc OrangeSpinnerView (UIKit, vòng xoay màu VArtThemeColor) để dùng trong SwiftUI. Khởi tạo với frame
/// cố định vì OrangeSpinnerView tính bán kính vòng tròn từ bounds ngay lúc init.
struct OrangeSpinner: UIViewRepresentable {
    var size: CGFloat = 60

    func makeUIView(context: Context) -> OrangeSpinnerView {
        OrangeSpinnerView(frame: CGRect(x: 0, y: 0, width: size, height: size))
    }

    func updateUIView(_ uiView: OrangeSpinnerView, context: Context) {}
}

struct TVGestureView: UIViewRepresentable {
    var isScrubbing: (() -> Bool)?
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onPressLeft: () -> Void
    var onPressRight: () -> Void
    var onPressDown: () -> Void
    var onPlayPause: () -> Void
    var onTouch: () -> Void
    var onExit: () -> Void
    var onMenuPress: () -> Void
    var onScrubChanged: ((CGFloat) -> Void)
    var onScrubEnded: () -> Void

    func makeUIView(context: Context) -> TVGestureUIView {
        let view = TVGestureUIView()
        view.onSwipeLeft  = onSwipeLeft
        view.onSwipeRight = onSwipeRight
        view.onSwipeUp  = onSwipeUp
        view.onSwipeDown  = onSwipeDown
        view.onPressLeft  = onPressLeft
        view.onPressRight = onPressRight
        view.onPressDown  = onPressDown
        view.onPlayPause  = onPlayPause
        view.onTouch  = onTouch
        view.onExit  = onExit
        view.onMenuPress  = onMenuPress
        view.onScrubChanged = onScrubChanged
        view.onScrubEnded = onScrubEnded
        
        // view.becomeFirstResponder()
        return view
    }

    func updateUIView(_ uiView: TVGestureUIView, context: Context) {
        uiView.isScrubbing = isScrubbing
        uiView.onSwipeLeft  = onSwipeLeft
        uiView.onSwipeRight = onSwipeRight
        uiView.onSwipeUp  = onSwipeUp
        uiView.onSwipeDown  = onSwipeDown
        uiView.onPressLeft  = onPressLeft
        uiView.onPressRight = onPressRight
        uiView.onPressDown  = onPressDown
        uiView.onPlayPause  = onPlayPause
        uiView.onTouch  = onTouch
        uiView.onExit  = onExit
        uiView.onMenuPress  = onMenuPress
        uiView.onScrubChanged = onScrubChanged
        uiView.onScrubEnded = onScrubEnded
    }
}
