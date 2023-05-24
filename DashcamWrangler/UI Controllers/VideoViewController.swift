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
        let _ = VideoPlayingStatusChange.observe {self.playingStatusChanged () }
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
    
    func setVideoViewForJourney(_ journey: Journey) {
        Task.init {
            do {
                let composition = try await journey.getMergedComposition()
                await MainActor.run {
                    
                    let playerItem = AVPlayerItem (asset: composition)
                    let videoPlayer = AVPlayer (playerItem: playerItem)
                    videoPlayer.preventsDisplaySleepDuringVideoPlayback = true
                    videoView.videoPlayer = videoPlayer
                    videoView.videoPlayer.pause()
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
    
    var isPaused: Bool { return videoView.videoPlayer.timeControlStatus == .paused }
    
    private func playingStatusChanged () {
        transportSegmentedControl.setImage(NSImage (systemSymbolName: isPaused ? "play.fill" : "pause.fill", accessibilityDescription: nil), forSegment: 1)
    }
    
    @IBAction func transportSegmentedControlClicked(_ sender: Any) {
        guard let ctl = sender as? NSSegmentedControl else { return }
        
        switch ctl.selectedSegment {
        case 0: if videoView.videoPlayer.currentTime() >= CMTime(seconds: 1, preferredTimescale: 10) {
            videoView.videoPlayer.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        } else {
            PrevJourneyNotify ().post()
        }
        case 1: if isPaused { videoView.videoPlayer.play() } else { videoView.videoPlayer.pause() }
        case 2: NextJourneyNotify ().post()
        default: break
        }
    }
    
}
