//
//  UserSelectionService.swift
//  VuaPhimBui
//
//  Created by Monster on 9/6/25.
//
import Foundation

struct TrackSelection: Codable {
    var subtitleID: Int?
    var secondarySubtitleID: Int?
    var audioID: Int?
    var audioLanguageTag: String?
    var subtitleLanguageTag: String?
}

struct UserSelection: Codable {
    var trackSelection: [Int: TrackSelection] // {video_id: {subtitle_id, audio_id}}
    var subtitleSetting: SubtitleSetting?
    var secondarySubtitleSetting: SecondarySubtitleSetting?
    var preferredAudioLanguageTag: String?
    var preferredSubtitleLanguageTag: String?
}

struct SubtitleSetting: Codable {
    var fontSize: Float
    var position: Float
    var fontName: String
    var backgroundOpacity: Float
    var isBold: Bool
    
    static let `default` = SubtitleSetting(fontSize: 53, position: 5, fontName: "Helvetica Neue", backgroundOpacity: 0, isBold: false)
}

struct SecondarySubtitleSetting: Codable {
    var fontSize: Float
    var position: Float
    var color: String
    
    static let `default` = SecondarySubtitleSetting(fontSize: 30, position: 10, color: "#FFFFFF")
}


class UserSelectionsService {
    static let shared = UserSelectionsService()
    private let key = "UserSelections"
    
    private init() {}

    private var userSelection: UserSelection {
        get {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode(UserSelection.self, from: data) {
                return decoded
            }
            return UserSelection(trackSelection: [:])
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    // MARK: - Track Selection

    func updateSubtitle(for videoID: Int, subtitleID: Int) {
        var current = userSelection
        var track = current.trackSelection[videoID] ?? TrackSelection()
        track.subtitleID = subtitleID
        current.trackSelection[videoID] = track
        userSelection = current
    }
    
    func updateSecondarySubtitle(for videoID: Int, secondarySubtitleID: Int?) {
        var current = userSelection
        var track = current.trackSelection[videoID] ?? TrackSelection()
        track.secondarySubtitleID = secondarySubtitleID
        current.trackSelection[videoID] = track
        userSelection = current
    }
    
    func updateAudio(for videoID: Int, audioID: Int) {
        var current = userSelection
        var track = current.trackSelection[videoID] ?? TrackSelection()
        track.audioID = audioID
        current.trackSelection[videoID] = track
        userSelection = current
    }

    func getTrackSelection(for videoID: Int) -> TrackSelection? {
        return userSelection.trackSelection[videoID]
    }
    
    // MARK: - Global Subtitle Setting

    func getSubtitleSetting() -> SubtitleSetting {
        return userSelection.subtitleSetting ?? SubtitleSetting.default
    }

    func updateFontName(_ fontName: String) {
        var current = userSelection
        var setting = current.subtitleSetting ?? SubtitleSetting.default
        setting.fontName = fontName
        current.subtitleSetting = setting
        userSelection = current
    }

    func updateFontSize(_ fontSize: Float) {
        var current = userSelection
        var setting = current.subtitleSetting ?? SubtitleSetting.default
        setting.fontSize = fontSize
        current.subtitleSetting = setting
        userSelection = current
    }

    func updatePosition(_ position: Float) {
        var current = userSelection
        var setting = current.subtitleSetting ?? SubtitleSetting.default
        setting.position = position
        current.subtitleSetting = setting
        userSelection = current
    }
    
    func updateBackgroundOpacity(_ backgroundOpacity: Float) {
        var current = userSelection
        var setting = current.subtitleSetting ?? SubtitleSetting.default
        setting.backgroundOpacity = backgroundOpacity
        current.subtitleSetting = setting
        userSelection = current
    }
    
    func updateIsBold(_ isBold: Bool) {
        var current = userSelection
        var setting = current.subtitleSetting ?? SubtitleSetting.default
        setting.isBold = isBold
        current.subtitleSetting = setting
        userSelection = current
    }
    
    // MARK: - Global SecondarySubtitle Setting

    func getSecondarySubtitleSetting() -> SecondarySubtitleSetting {
        return userSelection.secondarySubtitleSetting ?? SecondarySubtitleSetting.default
    }

    func updateSecondaryColor(_ color: String) {
        var current = userSelection
        var setting = current.secondarySubtitleSetting ?? SecondarySubtitleSetting.default
        setting.color = color
        current.secondarySubtitleSetting = setting
        userSelection = current
    }

    func updateSecondaryFontSize(_ fontSize: Float) {
        var current = userSelection
        var setting = current.secondarySubtitleSetting ?? SecondarySubtitleSetting.default
        setting.fontSize = fontSize
        current.secondarySubtitleSetting = setting
        userSelection = current
    }

    func updateSecondaryPosition(_ position: Float) {
        var current = userSelection
        var setting = current.secondarySubtitleSetting ?? SecondarySubtitleSetting.default
        setting.position = position
        current.secondarySubtitleSetting = setting
        userSelection = current
    }
    
    func updatePreferredAudioLanguage(_ languageTag: String) {
        var current = userSelection
        current.preferredAudioLanguageTag = languageTag
        userSelection = current
    }

    func getPreferredAudioLanguageTag() -> String? {
        return userSelection.preferredAudioLanguageTag
    }
    
    func updatePreferredSubtitleLanguage(_ languageTag: String) {
        var current = userSelection
        current.preferredSubtitleLanguageTag = languageTag
        userSelection = current
    }

    func getPreferredSubtitleLanguageTag() -> String? {
        return userSelection.preferredSubtitleLanguageTag
    }

    // MARK: - Clear

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
