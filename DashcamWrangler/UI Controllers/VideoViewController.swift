//
//  VideoViewController.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Cocoa
import AVFoundation

class VideoViewController: NSViewController {

    @IBOutlet weak var videoView: VideoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let _ = JourneySelectedNotify.observe { journey in
            self.setViewoViewForJourney(journey)
        }
    }
    
    func setViewoViewForJourney(_ journey: Journey) {
        Task.init {
            do {
                let composition = try await journey.getMergedComposition()
                await MainActor.run {
                    
                    let playerItem = AVPlayerItem (asset: composition)
                    let videoPlayer = AVPlayer (playerItem: playerItem)
                    videoPlayer.preventsDisplaySleepDuringVideoPlayback = true
                    videoView.videoPlayer = videoPlayer
                }
            } catch {
                await MainActor.run { videoView.videoPlayer = nil }
                
            }
        }
    }
    
}
