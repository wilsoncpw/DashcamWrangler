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
    @IBOutlet weak var transportSegmentedControl: NSSegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let _ = JourneySelectedNotify.observe { journeySelection in
            self.setVideoViewForJourney(journeySelection.journey)
            self.isFirst = journeySelection.isFirst
            self.isLast = journeySelection.isLast
        }
        
        let _ = VideoTickNotify.observe { self.handleVideoTick ()}
    }
    
    var isFirst = true {
        didSet {
            transportSegmentedControl.setEnabled(!isFirst, forSegment: 0)
        }
    }
    
    var isLast = true {
        didSet {
            transportSegmentedControl.setEnabled(!isLast, forSegment: 2)
        }
    }
    
    var paused = true {
        didSet {
            switch paused {
            case true:
                videoView.videoPlayer.pause()
                transportSegmentedControl.setImage(NSImage (systemSymbolName: "play.fill", accessibilityDescription: nil), forSegment: 1)
                
            case false:
                videoView.videoPlayer.play()
                transportSegmentedControl.setImage(NSImage (systemSymbolName: "pause.fill", accessibilityDescription: nil), forSegment: 1)
            }
        }
    }
    
    func setVideoViewForJourney(_ journey: Journey) {
        Task.init {
            do {
                let composition = try await journey.getMergedComposition()
                await MainActor.run {
                    
                    let playerItem = AVPlayerItem (asset: composition)
                    let videoPlayer = AVPlayer (playerItem: playerItem)
                    videoPlayer.preventsDisplaySleepDuringVideoPlayback = true
                    videoView.videoPlayer = videoPlayer
                    paused = true
                }
            } catch {
                await MainActor.run { videoView.videoPlayer = nil }
                
            }
        }
    }
    
    private func handleVideoTick () {
        if !isFirst { return }
        
        transportSegmentedControl.setEnabled(videoView.videoPlayer.currentTime() >= CMTime(seconds: 1, preferredTimescale: 10), forSegment: 0)
    }
    
    @IBAction func transportSegmentedControlClicked(_ sender: Any) {
        guard let ctl = sender as? NSSegmentedControl else { return }
        
        switch ctl.selectedSegment {
        case 0: if videoView.videoPlayer.currentTime() >= CMTime(seconds: 1, preferredTimescale: 10) {
            videoView.videoPlayer.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        } else {
            PrevJourneyNotify ().post()
        }
        case 1: paused = !paused
        case 2: NextJourneyNotify ().post()
        default: break
        }
    }
    
}
