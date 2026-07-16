//
//  AudioManager.swift
//  GameClassification
//
//  Created by Antigravity on 16/07/26.
//

import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()

    private var backgroundMusicPlayer: AVAudioPlayer?

    private init() {}

    func playBackgroundMusic() {
        // Set up the audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
        }

        guard backgroundMusicPlayer == nil else {
            if backgroundMusicPlayer?.isPlaying == false {
                backgroundMusicPlayer?.play()
            }
            return
        }

        guard let url = Bundle.main.url(forResource: "Background_Music_Rosetta", withExtension: "mp3") else {
            print("Background music file not found: Background_Music_Rosetta.mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // Loop infinitely
            player.prepareToPlay()
            player.play()
            backgroundMusicPlayer = player
        } catch {
            print("Failed to initialize background music player: \(error)")
        }
    }

    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
    }

    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }
}
