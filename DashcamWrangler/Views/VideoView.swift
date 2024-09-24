//
//  VideoView.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Cocoa
import AVFoundation

class VideoView: NSView, CALayerDelegate {
    
    class QuietLayoutManager : CAConstraintLayoutManager {
        
        static let instance = QuietLayoutManager ()
        
        override func layoutSublayers(of layer: CALayer) {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            super.layoutSublayers(of: layer)
            CATransaction.commit()
        }
    }
    
    private let viewLayer = CALayer ()
    private let videoPlayerLayer = AVPlayerLayer ()
    private let lineLayer = CAShapeLayer ()
    private let rangeStartLayer = CAShapeLayer ()
    private let rangeEndLayer = CAShapeLayer ()

    private var statusObservation: NSKeyValueObservation?
    private var readyObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var lineTargetPath: CGPath?
    private var draggingLine = false
    private var wasPlayingWhenDragStarted = false
    
    private enum mouseClickArea {
        case video
        case line
        case control
        case other
    }
    
    var videoPlayer: AVPlayer! {
        didSet {
           statusObservation = nil
           
           if let timeObserver = timeObserver {
               oldValue?.removeTimeObserver(timeObserver)
               self.timeObserver = nil
           }
           videoPlayerLayer.player = videoPlayer
           
           if let videoPlayer = videoPlayer {
               videoPlayer.actionAtItemEnd = .pause
               statusObservation = videoPlayer.observe (\.timeControlStatus, options: [.new]) { object, change in
                   self.playingStatusChanged ()
               }
           }
        }
    }
   
    override func awakeFromNib() {
        super.awakeFromNib()
        
        viewLayer.layoutManager = QuietLayoutManager.instance
        
        videoPlayerLayer.addConstraintsToFillSuperlayer(leftMargin: 10, topMargin: 0, rightMargin: 10, bottomMargin: 10)
        videoPlayerLayer.layoutManager = CAConstraintLayoutManager ()
        viewLayer.addSublayer(videoPlayerLayer)
        
        lineLayer.addConstraintsToFillSuperlayer(leftMargin: 0, topMargin: 0, rightMargin: 0, bottomMargin: 0)
        lineLayer.strokeColor = NSColor.red.cgColor
        lineLayer.fillColor = NSColor.red.cgColor
        lineLayer.delegate = self
        videoPlayerLayer.addSublayer(lineLayer)
        
        rangeStartLayer.addConstraintsToFillSuperlayer(leftMargin: 0, topMargin: 0, rightMargin: 0, bottomMargin: 0)
        rangeStartLayer.strokeColor = NSColor.blue.cgColor
        videoPlayerLayer.addSublayer(rangeStartLayer)
        
        rangeEndLayer.addConstraintsToFillSuperlayer(leftMargin: 0, topMargin: 0, rightMargin: 0, bottomMargin: 0)
        rangeEndLayer.strokeColor = NSColor.green.cgColor
        videoPlayerLayer.addSublayer(rangeEndLayer)
        
        self.layer = viewLayer
            
        readyObservation = videoPlayerLayer.observe(\.isReadyForDisplay, options: [.new]) { object, change in
            if let newValue = change.newValue {
                self.readyStatuschanged(isReady: newValue)
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        
        if draggingLine { return }
        
        switch getMouseClickArea(mouseEvent: event) {
        case .control: print ("control")
        case .line: NSCursor.pointingHand.set()
        case .video, .other: NSCursor.arrow.set()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        switch getMouseClickArea(mouseEvent: event) {
        case .video:
            if videoPlayer.timeControlStatus == .paused {
                videoPlayer.play()
            } else {
                videoPlayer.pause()
            }
        case .line:
            wasPlayingWhenDragStarted = videoPlayer.timeControlStatus != .paused
            videoPlayer.pause()
            draggingLine = true
        default: break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        
        if draggingLine {
            draggingLine = false
            if wasPlayingWhenDragStarted {
                videoPlayer.play()
                wasPlayingWhenDragStarted = false
            }
            
            switch getMouseClickArea(mouseEvent: event) {
            case .line: NSCursor.pointingHand.set()
            default: NSCursor.arrow.set()
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let duration = videoPlayer.currentItem?.duration, draggingLine else { return }
        
        let location = locationForEvent(event)
        
        // Calculate x pos = 0..videoRect.width
        let xPos = min (max (location.x - videoPlayerLayer.videoRect.minX, 0), videoPlayerLayer.videoRect.width)
        
        // Calculate new video CMTime as the ratio
        let newPos = CMTimeMultiplyByRatio(duration, multiplier: Int32 (xPos), divisor: Int32 (videoPlayerLayer.videoRect.width))
        
        videoPlayer.seek (to: newPos)
        updateLine()
        VideoTickNotify().post()
        tickCount = 0
    }
    
 
    override func mouseExited(with event: NSEvent) {
        if draggingLine {
            return
        }
        
        NSCursor.arrow.set()
    }
    
    // -------------------------------------------------------------------------------------
    /// Called at the start, and when the user changes appearance - eg. to dark mode
    ///
    /// nb.  This gets called before awakeFromNib
    override func viewDidChangeEffectiveAppearance() {
        let currentAppearance = NSAppearance.currentDrawing()
        if currentAppearance.name == .darkAqua || currentAppearance.name == .accessibilityHighContrastDarkAqua {
            viewLayer.backgroundColor = CGColor (red: 0.196078, green: 0.196078, blue: 0.196078, alpha: 1)
            videoPlayerLayer.backgroundColor = layer?.backgroundColor
        } else {
            viewLayer.backgroundColor = CGColor (red: 0.92549, green: 0.92549, blue: 0.92549, alpha: 1)
            videoPlayerLayer.backgroundColor = layer?.backgroundColor
        }
    }
       
    
    // -------------------------------------------------------------------------------------
    /// CALayerDelegate.layoutSublayers
    /// - Parameter layer: The line layer
    func layoutSublayers(of layer: CALayer) {
        updateOurTrackingAreas()
        updateLine()
    }
    
    private func updateOurTrackingAreas() {
        if let ourTrackingArea = (
            trackingAreas.first { layer in
                guard let userInfo = layer.userInfo else { return false }
                return userInfo ["videoPlayer"] as? Bool ?? false
            }
        ){
            removeTrackingArea(ourTrackingArea)
            addOurTrackingArea ()
        }
    }
    
    private func addOurTrackingArea () {
        let trackingArea = NSTrackingArea (rect: videoPlayerLayer.videoRect, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited], owner: self, userInfo: ["videoPlayer":true])
        addTrackingArea(trackingArea)
    }
     
    private func locationForEvent (_ event: NSEvent) -> CGPoint {
        let initialLocation = event.locationInWindow
        return videoPlayerLayer.convert(initialLocation, from: nil)
    }
    
    private func getMouseClickArea (mouseEvent: NSEvent) -> mouseClickArea {

        let location = locationForEvent(mouseEvent)
        
        if lineTargetPath?.contains(location) ?? false {
            return .line
        }
        
        if videoPlayerLayer.videoRect.contains(location) {
            return .video
        }
        
        return .other
    }
    
   
    private func updateLine () {
        
        guard let videoPlayer = videoPlayer, let maxTime = videoPlayer.currentItem?.duration.seconds, maxTime > 0 else {
            lineLayer.path = nil
            lineTargetPath = nil
            return
        }
        
        let time = videoPlayer.currentTime().seconds
        let ratio = CGFloat (time / maxTime)
        
        let rect = videoPlayerLayer.videoRect
        let x = 1 + rect.minX + (rect.width - 1) * ratio
        
        let path = CGMutablePath ()
        path.move(to: CGPoint (x: x, y: rect.minY))
        
        path.addLine(to: CGPoint (x: x+4.5, y: rect.minY-6))
        path.addLine(to: CGPoint (x: x+4.5, y: rect.minY-9))
        path.addLine(to: CGPoint (x: x-4.5, y: rect.minY-9))
        path.addLine(to: CGPoint (x: x-4.5, y: rect.minY-6))
        path.closeSubpath()
        
        path.addLine(to: CGPoint (x: x, y: rect.maxY))
        path.closeSubpath()

        lineLayer.path = path
        
                
        let lineCap = CGLineCap (from: lineLayer.lineCap)
        let lineJoin = CGLineJoin (from: lineLayer.lineJoin)
        
        let targetPath = path.copy(strokingWithWidth: 5, lineCap: lineCap, lineJoin: lineJoin, miterLimit: lineLayer.miterLimit)
        self.lineTargetPath = targetPath
    }
    
    func showRangeStartLine (rangeStartTime: CMTime?) {
        guard let rangeStartTime, let videoPlayer, let maxTime = videoPlayer.currentItem?.duration.seconds, maxTime > 0 else {
            rangeStartLayer.path = nil
            return
        }
        let ratio = CGFloat (rangeStartTime.seconds / maxTime)
        
        let rect = videoPlayerLayer.videoRect
        let x = 1 + rect.minX + (rect.width - 1) * ratio
        
        let path = CGMutablePath ()
        path.move(to: CGPoint (x: x, y: rect.minY))
        
        path.addLine(to: CGPoint (x: x, y: rect.maxY))
        path.closeSubpath()

        rangeStartLayer.path = path
    }
    
    func showRangeEndLine (rangeEndTime: CMTime?) {
        guard let rangeEndTime, let videoPlayer, let maxTime = videoPlayer.currentItem?.duration.seconds, maxTime > 0 else {
            rangeEndLayer.path = nil
            return
        }
        let ratio = CGFloat (rangeEndTime.seconds / maxTime)
        
        let rect = videoPlayerLayer.videoRect
        let x = 1 + rect.minX + (rect.width - 1) * ratio
        
        let path = CGMutablePath ()
        path.move(to: CGPoint (x: x, y: rect.minY))
        
        path.addLine(to: CGPoint (x: x, y: rect.maxY))
        path.closeSubpath()

        rangeEndLayer.path = path
    }
    
    
    private func playingStatusChanged () {
        VideoPlayingStatusChange().post()
    }
    
    private var tickCount = 0
    private func handleTick () {
        updateLine()
        tickCount += 1
        if tickCount == 10 {
            tickCount = 0
            VideoTickNotify().post()
        }
    }
    
    private func readyStatuschanged (isReady: Bool) {
        trackingAreas.forEach { trackingArea in
            removeTrackingArea(trackingArea)
        }
        
        if isReady {
            timeObserver = videoPlayer.addPeriodicTimeObserver(forInterval: CMTime (seconds: 0.1, preferredTimescale: 600), queue: nil) {[weak self] time in
                self?.handleTick()
            }
            
            addOurTrackingArea()
            tickCount = 0
        }
        updateLine()
    }
    
    private func playerDestroyed () {
        updateLine()
    }
    
    private func revealControls () {
//        print ("video")
    }
    

}

