import Foundation
import UIKit
import Libmpv
import AVKit

struct IntroState {
    var shouldShowSkip: Bool = false
    var endTimeMs: Int = 0
}

// warning: metal API validation has been disabled to ignore crash when playing HDR videos.
// Edit Scheme -> Run -> Diagnostics -> Metal API Validation -> Turn it off
// https://github.com/KhronosGroup/MoltenVK/issues/2226
final class MPVMetalViewController: UIViewController {
    var metalLayer = MetalLayer()
    var mpv: OpaquePointer!
    var playDelegate: MPVPlayerDelegate?
    lazy var queue = DispatchQueue(label: "mpv", qos: .userInitiated)
    
    var playUrl: URL?
    var hdrAvailable : Bool = false
    
    internal var seekTimer: Timer?
    private var bufferingTimer: Timer?
    private var timelineTimer: Timer?
    private var hideOverlayTimer: Timer?
    
    private var videoUrl: URL?
    internal var viewOffset: Int?
    private var ratingKey: String?
    internal var duration: Int?
    internal var listSubtitle: [PlexMediaPartStream]?
    internal var listAudioTrack: [PlexMediaPartStream]?
    internal var selectedSubtitleId: Int?
    internal var selectedSecondarySubtitleId: Int?
    internal var selectedAudioId: Int?
    internal var selectedSpeed: Float?
    internal var selectedMediaId: Int?
    internal var videoID: Int?
    internal var videoTitle: String?
    internal var thumbnailUrl: String?
    internal var playlist: [QueueItem]?
    internal var currentIndexVideo: Int?
    internal var grandVideoTitle: String?
    internal var ultraBlurColors: PlexUltraBlurColors?
    internal var markers: [PlexMarker]?
    internal var lastSeekTime: Double? = nil
    internal var listVersion: [PlexMedia]?
    /// Có giá trị khi nội dung đang phát đến từ Stremio — dùng để route việc lưu tiến độ xem
    /// sang StremioAccountAPI thay vì PlexAPI.sendTimelineUpdate (xem sendProgressUpdate(state:)).
    private var stremioContext: StremioPlaybackContext?
    /// URL video hiện đang nạp trong mpv — để biết khi vào lại player có phải cùng 1 video không (resume
    /// từ cache) hay video khác (load lại). nil = chưa nạp gì.
    private(set) var loadedVideoUrl: String?

    private var isInitLoad: Bool = true
    private var isInitSetSubtitle: Bool = true
    internal var isPlaying = true
    internal var isForcePauseFromResign = false
    internal var isInWatchTogether = false
    private var currentState = "playing"
    internal var introStartMs: Int = 990
    internal var introEndMs: Int = 53076
    internal var playbackSessionId: String = UUID().uuidString
    internal let isIpad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    var onPlaybackStateChange: ((String) -> Void)? = nil
    
    var onIntroDetected: ((IntroState) -> Void)?
    var onAudioTrackLoaded: ((Int) -> Void)?
    /// Gọi khi tự dò được track audio/subtitle nhúng sẵn trong file mà metadata truyền vào không biết trước
    /// (dùng cho SwiftUI cập nhật danh sách hiển thị trong MediaSettingsPanel).
    var onTracksDiscovered: (([PlexMediaPartStream]) -> Void)?

    
    private var loadingIndicator: OrangeSpinnerView!
    
    var hdrEnabled = false {
        didSet {
            // FIXME: target-colorspace-hint does not support being changed at runtime.
            // this option should be set as early as possible otherwise can cause issues
            // not recommended to use this way.
            if hdrEnabled {
                // checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "yes"))
            } else {
                // checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "no"))
            }
        }
    }
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [self.view]
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }

    override var canResignFirstResponder: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Controller dùng chung sống qua nhiều lần present — viewDidLoad chỉ chạy 1 lần, nên timer báo
        // tiến độ phải khởi động lại mỗi lần view xuất hiện (dừng ở viewWillDisappear).
        startUpdateTimelineTimer()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        metalLayer.frame = view.frame
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor

        view.layer.addSublayer(metalLayer)

        setupLoadingIndicator()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        metalLayer.frame = view.frame
    }
    
    func setupMpv() {
        // An toàn chống tạo 2 mpv context (leak): nếu đã có context rồi thì bỏ qua. Controller dùng chung
        // sống suốt vòng đời app nên setupMpv có thể bị gọi lại từ nhiều lần vào player — chỉ tạo 1 lần.
        guard mpv == nil else { return }

        mpv = mpv_create()
        if mpv == nil {
            print("failed creating context\n")
            exit(1)
        }
        
        // https://mpv.io/manual/stable/#options
#if DEBUG
        checkError(mpv_request_log_messages(mpv, "debug"))
#else
        checkError(mpv_request_log_messages(mpv, "no"))
#endif
#if os(macOS)
        checkError(mpv_set_option_string(mpv, "input-media-keys", "yes"))
#endif
        checkError(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer))
        checkError(mpv_set_option_string(mpv, "subs-match-os-language", "yes"))
        checkError(mpv_set_option_string(mpv, "subs-fallback", "yes"))
        checkError(mpv_set_option_string(mpv, "vo", "gpu-next"))
        checkError(mpv_set_option_string(mpv, "gpu-api", "vulkan"))
        checkError(mpv_set_option_string(mpv, "gpu-context", "moltenvk"))
        checkError(mpv_set_option_string(mpv, "hwdec", "videotoolbox"))
        checkError(mpv_set_option_string(mpv, "video-rotate", "no"))
        
        checkError(mpv_set_option_string(mpv, "hr-seek", "no"))

        
//        checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "yes")) // HDR passthrough
//        
//        // Ép mpv tự convert dải màu SDR (Rec.709) sang không gian Dolby Vision (BT.2020) của Apple TV
//        checkError(mpv_set_option_string(mpv, "target-prim", "bt.2020"))
//
//        // Ép chuyển đường cong ánh sáng từ SDR (Gamma) sang chuẩn HDR (PQ) để khớp khít rịt với Apple TV
//        checkError(mpv_set_option_string(mpv, "target-trc", "pq"))
//        
//        // 1. THUẬT TOÁN ĐIỆN ẢNH CHUẨN ĐỒNG BỘ: BT.2446a
//        // Thay vì spline, bt.2446a là thuật toán tối tân nhất của gpu-next chuyên dùng để ánh xạ SDR sang HDR/Dolby.
//        // Nó xử lý vùng chuyển sắc (gradient) của màu da người và bóng tối cực kỳ mịn, triệt tiêu hoàn toàn hiện tượng gắt hình.
//        checkError(mpv_set_option_string(mpv, "tone-mapping", "bt.2446a"))
//        // checkError(mpv_set_option_string(mpv, "tone-mapping", "mobius"))
//
//        // 2. KHÓA ĐỘ SÁNG ĐỈNH QUÝ TỘC: 100 nits
//        // Dolby Vision Dark yêu cầu độ sáng tham chiếu chuẩn phòng tối là chính xác 100 nits.
//        // Khóa cứng dòng này sẽ giúp TV C7K hiểu đúng ý đồ, không bao giờ đẩy đèn nền lên quá cao gây chói lòa.
//        checkError(mpv_set_option_string(mpv, "target-peak", "100"))
//        
////        checkError(mpv_set_option_string(mpv, "tone-mapping-visualize", "yes"))  // only for dbetebugging purposes
////        checkError(mpv_set_option_string(mpv, "profile", "fast"))   // can fix frame drop in poor device when play 4k
//        
//        // Trả Audio về mức an toàn, chất lượng PCM không nén cao nhất cho loa B&O
//        checkError(mpv_set_option_string(mpv, "ao", "audiounit"))
//        checkError(mpv_set_option_string(mpv, "audio-format", "s32"))
//        checkError(mpv_set_option_string(mpv, "audio-channels", "auto-safe"))
        checkError(mpv_initialize(mpv))
        
        mpv_observe_property(mpv, 0, MPVProperty.videoParamsSigPeak, MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, MPVProperty.pausedForCache, MPV_FORMAT_FLAG)
        mpv_set_wakeup_callback(self.mpv, { (ctx) in
            let client = unsafeBitCast(ctx, to: MPVMetalViewController.self)
            client.readEvents()
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        setupNotification()
    }

    public func setupNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc public func enterBackground() {
        // fix black screen issue when app enter foreground again
        pause()
        checkError(mpv_set_option_string(mpv, "vid", "no"))
    }
    
    @objc public func enterForeground() {
        checkError(mpv_set_option_string(mpv, "vid", "auto"))
        play()
    }
    
    func loadFile(
        _ url: URL
    ) {
        let seekTime = Double(self.viewOffset ?? 0) / 1000
        checkError(mpv_set_option_string(mpv, "start", "\(seekTime)"))

        var args = [url.absoluteString]
        let options = [String]()
        
        args.append("replace")
        
        if !options.isEmpty {
            args.append(options.joined(separator: ","))
        }
        print("loadfile args: \(args)")
        command("loadfile", args: args)
    }

    internal func handlePlaybackStatusChange(_ state: String) {
        switch state {
        case "opening":
            self.loadingIndicator.startAnimating()
        case "buffering":
            self.loadingIndicator.startAnimating()
            
        case "seeking":
            self.loadingIndicator.startAnimating()
        case "seeked":
            self.loadingIndicator.stopAnimating()
        case "playing":
            self.currentState = "playing"

            // Nguồn không cung cấp trước danh sách track nhúng sẵn trong file (vd Stremio) — sau khi mpv
            // load xong, tự dò track-list của chính mpv để bổ sung, không phải chờ metadata ngoài.
            if self.isInitLoad || self.isInitSetSubtitle {
                let embeddedTracks = self.discoverEmbeddedTracks()
                if !embeddedTracks.isEmpty {
                    self.listAudioTrack = (self.listAudioTrack ?? []) + embeddedTracks.filter { $0.streamType == 2 }
                    self.listSubtitle = (self.listSubtitle ?? []) + embeddedTracks.filter { $0.streamType == 3 }
                    self.onTracksDiscovered?(embeddedTracks)
                }
            }

            if self.isInitLoad {
                self.loadAudioSelection()
                self.isInitLoad = false            }

            if self.isInitSetSubtitle {
                self.loadSubtitleSelection()
                self.isInitSetSubtitle = false
            }
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            
            if self.loadingIndicator.isHidden == false {
                self.loadingIndicator.stopAnimating()
            }
            
        case "paused":
            self.currentState = "paused"
            sendProgressUpdate(state: self.currentState)

            UIApplication.shared.isIdleTimerDisabled = false

        case "idle", "stopped", "ended":
            self.currentState = "stopped"
            sendProgressUpdate(state: self.currentState)
            self.loadingIndicator.stopAnimating()

        default:
            break
        }
        
        DispatchQueue.main.async {
            self.onPlaybackStateChange?(state)
        }
    }
    
    func togglePause() {
        getFlag(MPVProperty.pause) ? play() : pause()
    }
    
    func play() {
        setFlag(MPVProperty.pause, false)
    }
    
    func pause() {
        setFlag(MPVProperty.pause, true)
    }
    
    private func getDouble(_ name: String) -> Double {
        guard mpv != nil else { return 0.0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }
    
    private func getString(_ name: String) -> String? {
        guard mpv != nil else { return nil }
        let cstr = mpv_get_property_string(mpv, name)
        let str: String? = cstr == nil ? nil : String(cString: cstr!)
        mpv_free(cstr)
        return str
    }
    
    private func getFlag(_ name: String) -> Bool {
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &data)
        return data > 0
    }
    
    private func setFlag(_ name: String, _ flag: Bool) {
        guard mpv != nil else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &data)
    }
    
    
    func command(
        _ command: String,
        args: [String?] = [],
        checkForErrors: Bool = true,
        returnValueCallback: ((Int32) -> Void)? = nil
    ) {
        guard mpv != nil else {
            return
        }
        var cargs = makeCArgs(command, args).map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
        defer {
            for ptr in cargs where ptr != nil {
                free(UnsafeMutablePointer(mutating: ptr!))
            }
        }
        //print("\(command) -- \(args)")
        let returnValue = mpv_command(mpv, &cargs)
        if checkForErrors {
            checkError(returnValue)
        }
        if let cb = returnValueCallback {
            cb(returnValue)
        }
    }

    private func makeCArgs(_ command: String, _ args: [String?]) -> [String?] {
        if !args.isEmpty, args.last == nil {
            fatalError("Command do not need a nil suffix")
        }
        
        var strArgs = args
        strArgs.insert(command, at: 0)
        strArgs.append(nil)
        
        return strArgs
    }
    
    func readEvents() {
        queue.async { [weak self] in
            guard let self else { return }
            
            while self.mpv != nil {
                let event = mpv_wait_event(self.mpv, 0)
                if event?.pointee.event_id == MPV_EVENT_NONE {
                    break
                }
                
                switch event!.pointee.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    let dataOpaquePtr = OpaquePointer(event!.pointee.data)
                    if let property = UnsafePointer<mpv_event_property>(dataOpaquePtr)?.pointee {
                        let propertyName = String(cString: property.name)
                        switch propertyName {
                        case MPVProperty.pause:
                            let isPaused = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee ?? true
                            DispatchQueue.main.async {
                                self.isPlaying = !isPaused
                                self.handlePlaybackStatusChange(isPaused ? "paused" : "playing")
                            }
                        case MPVProperty.pausedForCache:
                            let buffering = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee ?? true
                            DispatchQueue.main.async {
                                self.handlePlaybackStatusChange(buffering ? "buffering" : "playing")
                                self.playDelegate?.propertyChange(mpv: self.mpv, propertyName: propertyName, data: buffering)
                            }
                        case MPVProperty.seeking:
                            let isSeeking = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee ?? true
                            DispatchQueue.main.async {
                                self.handlePlaybackStatusChange(isSeeking ? "seeking" : "seeked")
                            }

                        case MPVProperty.videoParamsSigPeak:
                            if let sigPeak = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                                DispatchQueue.main.async {
                                    let maxEDRRange = self.view.window?.screen.potentialEDRHeadroom ?? 1.0
                                    // display screen support HDR and current playing HDR video
                                    let isHDRVideo = sigPeak > 1.0
                                    let displaySupportsHDR = maxEDRRange > 1.0

                                    self.hdrAvailable = displaySupportsHDR && isHDRVideo

                                    // self.setSystemDisplayMode(hdr: self.hdrAvailable)

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: sigPeak
                                    )
                                }
                            }
                        default: break
                        }
                    }
                case MPV_EVENT_SHUTDOWN:
                    print("event: shutdown\n");
                    mpv_terminate_destroy(mpv);
                    mpv = nil;
                    break;
                case MPV_EVENT_LOG_MESSAGE:
                    let msg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event!.pointee.data))
                    print("[\(String(cString: (msg!.pointee.prefix)!))] \(String(cString: (msg!.pointee.level)!)): \(String(cString: (msg!.pointee.text)!))", terminator: "")
                case MPV_EVENT_END_FILE:
                    let endFile = UnsafeMutablePointer<mpv_event_end_file>(OpaquePointer(event!.pointee.data))
                    if let raw = endFile?.pointee.reason, raw.rawValue == 0 {
                        if let currentIndex = currentIndexVideo {
                            Task {
                                await self.reloadVideoWithNewIndex(index: currentIndex + 1)
                            }
                        }
                    }
                default:
                    let eventName = mpv_event_name(event!.pointee.event_id )
                    print("event: \(String(cString: (eventName)!))");
                }
                
            }
        }
    }
    
    
    private func checkError(_ status: CInt) {
        if status < 0 {
            print("MPV API error: \(String(cString: mpv_error_string(status)))\n")
        }
    }
    
    func destroy() {
        guard mpv != nil else { return }

        loadedVideoUrl = nil

        // setSystemDisplayMode(hdr: false)

        setFlag(MPVProperty.pause, true)

        checkError(mpv_set_option_string(mpv, "vid", "no"))

        mpv_set_wakeup_callback(mpv, nil, nil)
        
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print("bLoopTV: lỗi deactivate session: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {

            mpv_terminate_destroy(self.mpv)
            self.mpv = nil

            self.metalLayer.removeFromSuperlayer()
        }
    }
    
    func seekToSeconds(seconds: Double) {
        self.command("seek", args: ["\(seconds)", "absolute", "exact"])
    }
    
    
    /// Nếu urlString đã là URL tuyệt đối (vd link phụ đề rời từ addon Stremio) thì dùng thẳng, không
    /// ký lại qua PlexAPI (chỉ nên áp dụng cho key tương đối của Plex).
    private func resolvedSubtitleURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        return PlexAPI.shared.getVideoURL(urlString: urlString)
    }

    func loadSubtitleSelection() {
        guard let streamingVideoID = videoID else { return }
        guard let subtitles = listSubtitle else { return }

        let userSelection = UserSelectionsService.shared.getTrackSelection(for: streamingVideoID)
        // Chưa từng chọn ngôn ngữ ưu tiên thì mặc định tiếng Việt.
        let preferredLanguage = UserSelectionsService.shared.getPreferredSubtitleLanguageTag() ?? "vi"

        let selectedSubtitle: PlexMediaPartStream? =
            // 1. Tập này đã từng chọn cụ thể
            subtitles.first(where: { userSelection?.subtitleID == $0.id })
            // 2. Khớp language tag ưu tiên (setting đã lưu, hoặc mặc định "vi")
            ?? subtitles.first(where: { $0.languageTag == preferredLanguage })
            // 3. Server default
            ?? subtitles.first(where: { $0.selected == true })
            // 4. Không khớp ngôn ngữ nào (vd addon để lang "unknown") nhưng có sẵn sub rời thì vẫn ưu tiên dùng
            ?? subtitles.first(where: { $0.url != nil })

        if let checkedSelectedSubtitle = selectedSubtitle {
            selectedSubtitleId = checkedSelectedSubtitle.id
            if let subtitleUrlString = checkedSelectedSubtitle.url {
                reloadMediaWithExternalSubtitle(
                    urlString: resolvedSubtitleURL(subtitleUrlString),
                    codec: checkedSelectedSubtitle.codec
                )
            } else {
                selectSubtitle(subtitleTrack: checkedSelectedSubtitle)
            }
        }
    }
    
    func loadAudioSelection() {
        guard let streamingVideoID = videoID else { return }
        guard let audios = listAudioTrack, !audios.isEmpty else { return }

        let userSelection = UserSelectionsService.shared.getTrackSelection(for: streamingVideoID)
        let preferredLanguage = UserSelectionsService.shared.getPreferredAudioLanguageTag()

        let selectedAudioTrack: PlexMediaPartStream? =
            audios.first(where: { userSelection?.audioID == $0.id })
            ?? audios.first(where: { preferredLanguage != nil && $0.languageTag == preferredLanguage })
            ?? audios.first(where: { $0.selected == true })

        if let track = selectedAudioTrack,
           let audioIndex = track.index,
           let audioId = getMPVTrackID(fromFFIndex: audioIndex) {
            selectedAudioId = track.id
            command("set", args: ["aid", "\(audioId)"])
            
            DispatchQueue.main.async {
                self.onAudioTrackLoaded?(track.id)
            }
        }
    }
    
    func selectSubtitle(subtitleTrack: PlexMediaPartStream) {
        if let subtitleIndex = subtitleTrack.index {
            // Internal subtitle
            if let id = getMPVTrackID(fromFFIndex: subtitleIndex) {
                let sid = Int64(id)
                command("set", args: ["sid", "\(sid)"])
            } else {
                print("Not found any sid with ff-index  \(subtitleIndex)")
            }
        } else if let subtitleUrlString = subtitleTrack.url {
            reloadMediaWithExternalSubtitle(urlString: resolvedSubtitleURL(subtitleUrlString), codec: subtitleTrack.codec)
        }
        if let streamingVideoID = self.videoID {
            UserSelectionsService.shared.updateSubtitle(for: streamingVideoID, subtitleID: subtitleTrack.id)

            if let tag = subtitleTrack.languageTag {
                UserSelectionsService.shared.updatePreferredSubtitleLanguage(tag)
            }
        }
    }
    
    func disableSubtitle() {
        command("set", args: ["sid", "no"])
    }
    
    func selectAudioTrack(audioTrack: PlexMediaPartStream) {
        if let audioIndex = audioTrack.index {
            if let audioId = getMPVTrackID(fromFFIndex: audioIndex) {
                command("set", args: ["aid", "\(audioId)"])
            }
        }
        if let streamingVideoID = self.videoID {
            UserSelectionsService.shared.updateAudio(for: streamingVideoID, audioID: audioTrack.id)

            if let tag = audioTrack.languageTag {
                UserSelectionsService.shared.updatePreferredAudioLanguage(tag)
            }
        }
    }
    
    func downloadExternalSubtitle(url: URL, fileName: String) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documents.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    func removeExternalSubtitle() -> Void {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let subtitlePath = documents.appendingPathComponent("subtitle.srt")
        
        if FileManager.default.fileExists(atPath: subtitlePath.path) {
            do {
                try FileManager.default.removeItem(at: subtitlePath)
                print("Subtitle file removed")
            }
            catch {
                print("Cannot remove subtitle:", error)
            }
        }

    }
    
    internal func reloadMediaWithExternalSubtitle(urlString: String, codec: String) {
        guard let url = URL(string: urlString) else { return }
        
        if codec == "ass" { // ass subtitles has very large size, which will caused block UI
            
            let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
                guard let self = self,
                      let localURL = localURL,
                      error == nil else { return }
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("ass")
                
                do {
                    try FileManager.default.copyItem(at: localURL, to: tempURL)
                    
                    DispatchQueue.main.async {
                        self.command("sub-add", args: [tempURL.path])
                    }
                } catch {
                    print("❌ Error copying subtitle: \(error)")
                }
            }
            task.resume()
            
        } else {
            command("sub-add", args: [urlString])
        }
    }

    internal func cleanupAllExternalSubtitles() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "ass" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    /// Tự dò track audio/subtitle nhúng sẵn trong file qua track-list của chính mpv (mpv tự parse được,
    /// không cần metadata ngoài) — bỏ qua track nào ff-index đã có sẵn trong listAudioTrack/listSubtitle
    /// (tránh trùng với track Plex đã biết trước).
    func discoverEmbeddedTracks() -> [PlexMediaPartStream] {
        guard let cStr = mpv_get_property_string(self.mpv, "track-list") else { return [] }
        defer { mpv_free(cStr) }

        let jsonStr = String(cString: cStr)
        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        var audioResults: [PlexMediaPartStream] = []
        var subtitleResults: [PlexMediaPartStream] = []

        for track in array {
            guard let type = track["type"] as? String, type == "audio" || type == "sub",
                  let ffIndex = track["ff-index"] as? Int else { continue }

            let streamType = type == "audio" ? 2 : 3
            let knownTracks = streamType == 2 ? listAudioTrack : listSubtitle
            if knownTracks?.contains(where: { $0.index == ffIndex }) == true { continue }

            let lang = track["lang"] as? String
            let title = track["title"] as? String
            let codec = track["codec"] as? String ?? ""
            let isDefault = track["default"] as? Bool ?? false
            let displayName = title ?? lang.map { $0.uppercased() } ?? "Track \(ffIndex + 1)"

            let entry = PlexMediaPartStream(
                id: 100_000 + ffIndex, // tránh đụng id đã dùng cho track ngoài
                streamType: streamType,
                title: displayName,
                displayTitle: displayName,
                extendedDisplayTitle: displayName,
                codec: codec,
                index: ffIndex,
                url: "",
                selected: isDefault,
                languageTag: lang ?? ""
            )

            if streamType == 2 {
                audioResults.append(entry)
            } else {
                subtitleResults.append(entry)
            }
        }

        // Sub nhúng chỉ lấy tiếng Việt/Anh cho gọn; file không có 2 ngôn ngữ này thì vẫn giữ hết để
        // không mất hẳn lựa chọn phụ đề.
        let normalizedLangs: Set<String> = ["vi", "vie", "en", "eng"]
        let viEnSubtitles = subtitleResults.filter {
            normalizedLangs.contains(($0.languageTag ?? "").lowercased())
        }
        let filteredSubtitles = viEnSubtitles.isEmpty ? subtitleResults : viEnSubtitles

        let results = audioResults + filteredSubtitles

        return results
    }

    func getMPVTrackID(fromFFIndex ffIndex: Int) -> Int? {
        guard let cStr = mpv_get_property_string(self.mpv, "track-list") else { return nil }
        defer { mpv_free(cStr) }

        let jsonStr = String(cString: cStr)
        if let data = jsonStr.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for track in array {
                if let type = track["type"] as? String,
                   (type == "audio" || type == "sub"),
                   let trackFFIndex = track["ff-index"] as? Int,
                   trackFFIndex == ffIndex {
                    return track["id"] as? Int
                }
            }
        }
        return nil
    }
    
    func getTimePos() -> Double {
        guard mpv != nil else { return 0 }
        var timePos: Double = 0
        mpv_get_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &timePos)
        return timePos
    }

    func getDuration() -> Double {
        guard mpv != nil else { return 0 }
        var dur: Double = 0
        mpv_get_property(mpv, "duration", MPV_FORMAT_DOUBLE, &dur)
        return dur
    }

    /// Lưu tiến độ xem — route sang StremioAccountAPI nếu nội dung đến từ Stremio, ngược lại giữ
    /// nguyên hành vi cũ (PlexAPI.sendTimelineUpdate) cho nội dung Plex.
    private func sendProgressUpdate(state: String) {
        if let context = stremioContext {
            guard let authKey = StremioAccountAPI.shared.authKey else { return }
            let timeOffsetMs = self.viewOffset ?? 0
            let liveDurationMs = Int(getDuration() * 1000)
            let durationMs = liveDurationMs > 0 ? liveDurationMs : (self.duration ?? 0)
            Task {
                await StremioAccountAPI.shared.updateLibraryItem(
                    authKey: authKey,
                    context: context,
                    timeOffsetMs: timeOffsetMs,
                    durationMs: durationMs
                )
            }
        } else {
            PlexAPI.shared.sendTimelineUpdate(
                ratingKey: self.ratingKey ?? "",
                time: self.viewOffset ?? 0,
                state: state,
                duration: self.duration ?? 0,
                playbackSessionId: playbackSessionId
            )
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopUpdateTimelineTimer()

        sendProgressUpdate(state: "stopped")
        self.resignFirstResponder()

        // Re-enable idle timer when leaving
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func startUpdateTimelineTimer() {
        stopUpdateTimelineTimer()
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.sendProgressUpdate(state: self.currentState)
        }

    }
    
    func stopUpdateTimelineTimer() {
        timelineTimer?.invalidate()
        timelineTimer = nil
    }

    /// Vào player: nếu cùng video đang còn trong buffer thì RESUME ngay (không load lại), khác video (hoặc
    /// lần đầu) thì load mới. Trả về true nếu là resume (để VideoPlayerView không seek/không init lại UI).
    @discardableResult
    func loadOrResume(playbackData: PlaybackData) -> Bool {
        if mpv != nil, loadedVideoUrl == playbackData.videoUrl {
            // Cùng video, buffer/cache còn nguyên → chỉ cần phát tiếp từ đúng vị trí mpv đang đứng.
            activateBloopAudioSession()
            play()
            return true
        }

        initPlayer(playbackData: playbackData, shouldSetupMpv: mpv == nil)
        loadedVideoUrl = playbackData.videoUrl
        return false
    }

    func initPlayer(playbackData: PlaybackData, shouldSetupMpv: Bool = true) {
        // Reset cờ init để chọn audio/phụ đề mặc định chạy lại cho video mới (controller dùng lại nhiều lần).
        self.isInitLoad = true
        self.isInitSetSubtitle = true
        // Session mới cho mỗi video mới (controller dùng chung không tự đổi như trước khi mỗi lần tạo mới).
        self.playbackSessionId = UUID().uuidString

        self.activateBloopAudioSession()
        self.viewOffset = playbackData.viewOffset
        self.ratingKey = playbackData.ratingKey
        self.duration = playbackData.duration
        self.videoID = playbackData.videoID
        self.videoTitle = playbackData.videoTitle
        self.thumbnailUrl = playbackData.thumbnailUrl
        self.currentIndexVideo = playbackData.currentIndex
        self.grandVideoTitle = playbackData.grandVideoTitle
        self.ultraBlurColors = playbackData.ultraBlurColors
        self.markers = playbackData.markers
        self.selectedMediaId = playbackData.selectedMediaId
        self.stremioContext = playbackData.stremioContext

        listSubtitle = playbackData.mediaPartStreams.filter {
            $0.streamType == 3
        }

        listAudioTrack = playbackData.mediaPartStreams.filter {
            $0.streamType == 2
        }
        
        listVersion = playbackData.versions
        
        self.playlist = playbackData.playlist
        
        if (shouldSetupMpv) {
            setupMpv()
        }
        
        self.videoUrl = URL(string: playbackData.videoUrl)
        
        if let url = videoUrl {
            loadFile(url)
        }
        
        initSubtitleSettings()
    }
    
    private func initSubtitleSettings() {
        let subtitleSetting = UserSelectionsService.shared.getSubtitleSetting()

        checkError(mpv_set_property_string(self.mpv, "sub-font", subtitleSetting.fontName))
        checkError(mpv_set_property_string(self.mpv, "sub-font-size", "\(subtitleSetting.fontSize)"))
        checkError(mpv_set_property_string(self.mpv, "sub-pos", "\(100 - subtitleSetting.position)"))
        checkError(mpv_set_property_string(self.mpv, "sub-line-spacing", "15"))
        checkError(mpv_set_property_string(self.mpv, "sub-color", "#D9FFFFFF"))
        // checkError(mpv_set_property_string(self.mpv, "sub-color", "#FFFFFF"))
        
        checkError(mpv_set_property_string(self.mpv, "sub-border-style", "background-box"))
        checkError(mpv_set_property_string(self.mpv, "sub-outline-size", "3.0"))
        checkError(mpv_set_property_string(self.mpv, "sub-back-color", "0.0/0.0/0.0/\(subtitleSetting.backgroundOpacity)"))
        
        checkError(mpv_set_property_string(self.mpv, "secondary-sub-visibility", "no"))
        checkError(mpv_set_property_string(self.mpv, "sub-bold", subtitleSetting.isBold ? "yes" : "no"))
        checkError(mpv_set_property_string(self.mpv, "sub-italic", "no"))
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopUpdateTimelineTimer()
        removeExternalSubtitle()
        cleanupAllExternalSubtitles()
    }
    
    
    func setupLoadingIndicator() {
        let spinnerSize: CGFloat = 60
        loadingIndicator = OrangeSpinnerView(frame: CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize))
        view.addSubview(loadingIndicator)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: spinnerSize),
            loadingIndicator.heightAnchor.constraint(equalToConstant: spinnerSize),
        ])
    }
    
//    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
//        print("presses began pressed")
//        guard let press = presses.first else {
//            super.pressesBegan(presses, with: event)
//            return
//        }
//
//        switch press.type {
//        case .leftArrow:
//            handleLeftPress()
//
//        case .rightArrow:
//            handleRightPress()
//
//        default:
//            super.pressesBegan(presses, with: event)
//        }
//    }
    
    private func handleLeftPress() {
        seekRelative(-10)
    }

    private func handleRightPress() {
        seekRelative(10)
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Disable idle timer to keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func seekRelative(_ seconds: Double) {
        self.command(
            "seek",
            args: ["\(seconds)", "relative", "exact"]
        )
    }
    
    func getBufferProgress(duration: Int) -> Double {
        guard mpv != nil else { return 0 }
        
        var timePos: Double = 0
        var cacheDur: Double = 0
        
        mpv_get_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &timePos)
        mpv_get_property(mpv, "demuxer-cache-duration", MPV_FORMAT_DOUBLE, &cacheDur)
        
        let durationSec = Double(duration) / 1000.0
        guard durationSec > 0 else { return 0 }
        
        let bufferEnd = min(timePos + cacheDur, durationSec)
        return bufferEnd / durationSec
    }
    
    func activateBloopAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
            print("bLoopTV: AVAudioSession gài bẫy Dolby Atmos thành công!")
        } catch {
            print("bLoopTV: Không thể kích hoạt AudioSession: \(error)")
        }
    }
    
    private func setSystemDisplayMode(hdr: Bool) {
        #if os(tvOS)

        guard #available(tvOS 11.2, *) else { return }

        let screen = UIScreen.main

        guard
            screen.responds(to: Selector(("avDisplayManager"))),
            let displayManager = screen.value(forKey: "avDisplayManager") as? NSObject
        else {
            return
        }

        if hdr {
            // Allow HDR / Dolby Vision
            displayManager.setValue(nil, forKey: "preferredDisplayCriteria")
        } else {

            let criteriaClass = NSClassFromString("AVDisplayCriteria") as? NSObject.Type

            if let criteria = criteriaClass?.init() {

                criteria.setValue(60, forKey: "refreshRate")

                // Force SDR
                criteria.setValue("SDR", forKey: "videoDynamicRange")

                displayManager.setValue(criteria, forKey: "preferredDisplayCriteria")
            }
        }

        #endif
    }
    
    func reloadVideoWithNewIndex(index: Int) async {
        print("index: \(index)")
        let queueItemByIndex = playlist?.first {
            $0.queueIndex == index
        }
        
        if let queueItem = queueItemByIndex {
            do {
                let metadataDetailData = try await PlexAPI.shared.fetchMetadataDetailAsync(id: queueItem.ratingKey)
                print("metadataDetailData: \(metadataDetailData)")
                
                if let medias = metadataDetailData.medias {
                    if isPlaying == false {
                        isPlaying = true
                    }
                    let dataPart = medias[0].parts[0]
                    initPlayer(playbackData: PlaybackData(
                        videoUrl: dataPart.url,
                        videoTitle: "\(queueItem.grandTitle) - M\(metadataDetailData.seasonIndex ?? 1)•T\(metadataDetailData.episodeIndex ?? 1)",
                        grandVideoTitle: grandVideoTitle ?? "",
                        viewOffset: metadataDetailData.viewOffset ?? 0,
                        duration: metadataDetailData.duration,
                        videoID: dataPart.id,
                        grandVideoID: dataPart.id,
                        ratingKey: queueItem.ratingKey,
                        thumbnailUrl: metadataDetailData.poster ?? "",
                        mediaPartStreams: dataPart.streams,
                        currentIndex: index,
                        playlist: playlist ?? [],
                        ultraBlurColors: ultraBlurColors ?? PlexUltraBlurColors(
                            topLeft: "#000000",
                            topRight: "#000000",
                            bottomRight: "#000000",
                            bottomLeft: "#000000"
                        ),
                        markers: metadataDetailData.markers,
                        versions: medias,
                        selectedMediaId: medias[0].id
                    ), shouldSetupMpv: false)
                } else {
                    print("not had any media")
                }
            } catch {
                print("error fetch detail:", error)
            }
        } else {
            print("not had any queue item by index")
        }
    }
}
