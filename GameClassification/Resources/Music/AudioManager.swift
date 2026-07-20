//
//  AudioManager.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 16/07/26.
//

import Foundation
import AVFoundation

@MainActor
class AudioManager {
    static let shared = AudioManager()

    private var backgroundMusicPlayer: AVAudioPlayer?
    private var typingPlayer: AVAudioPlayer?
    
    enum BackgroundTrack {
        case rosetta
        case heartbeat
        case menu
        case none
    }
    
    private(set) var currentTrack: BackgroundTrack = .none
    private var sfxPlayers: [String: AVAudioPlayer] = [:]

    private init() {}

    func playMainMenuMusic() {
        playTrack(.menu)
    }

    func playBackgroundMusic() {
        // Default to playing Rosetta music
        playTrack(.rosetta)
    }

    func updateBackgroundMusic(forEnergy energy: Double) {
        // If we are not playing in-game background music (e.g. main menu or none), do nothing
        guard currentTrack == .rosetta || currentTrack == .heartbeat else { return }

        let targetTrack: BackgroundTrack = energy <= 20.0 ? .heartbeat : .rosetta
        if currentTrack != targetTrack {
            playTrack(targetTrack)
        }
    }

    private func playTrack(_ track: BackgroundTrack) {
        if currentTrack == track && backgroundMusicPlayer?.isPlaying == true {
            return
        }

        // Set up the audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
        }

        // Stop current background music first
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        currentTrack = track

        let resourceName: String
        switch track {
        case .rosetta:
            resourceName = "Background_Music_Rosetta"
        case .heartbeat:
            resourceName = "Low_Energy_Heartbeat_Rosetta"
        case .menu:
            resourceName = "Gameplay_until_prologue"
        case .none:
            return
        }

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3") else {
            print("Background music file not found: \(resourceName).mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // Loop infinitely
            player.prepareToPlay()
            player.play()
            backgroundMusicPlayer = player
        } catch {
            print("Failed to initialize background music player for \(resourceName): \(error)")
        }
    }

    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        currentTrack = .none
    }

    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }

    func playTypingSound() {
        guard let url = Bundle.main.url(forResource: "Typing_sound", withExtension: "mp3") else {
            print("Typing sound file not found: Typing_sound.mp3")
            return
        }
        do {
            if typingPlayer == nil {
                typingPlayer = try AVAudioPlayer(contentsOf: url)
                typingPlayer?.numberOfLoops = -1
            }
            if typingPlayer?.isPlaying == false {
                typingPlayer?.currentTime = 0
                typingPlayer?.play()
            }
        } catch {
            print("Failed to play typing sound: \(error)")
        }
    }

    func stopTypingSound() {
        typingPlayer?.stop()
        typingPlayer = nil
    }

    // MARK: - Sound Effects (SFX)

    func playBackSound() {
        playSoundEffect(name: "Canvas_Back_Rosetta")
    }

    func playCorrectSound() {
        playSoundEffect(name: "Canvas_Correct_Rosetta")
    }

    func playEraseSound() {
        playSoundEffect(name: "Canvas_Erase_Rosetta")
    }

    func playWrongSound() {
        playSoundEffect(name: "Canvas_Wrong_Rosetta")
    }

    func playButtonSound() {
        playSoundEffect(name: "Gameplay_Button_Rosetta")
    }

    private func playSoundEffect(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("Sound effect file not found: \(name).mp3")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            sfxPlayers[name] = player
        } catch {
            print("Failed to play sound effect \(name): \(error)")
        }
    }
}
