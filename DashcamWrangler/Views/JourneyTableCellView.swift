//
//  JourneyTableCellView.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa
import AVFoundation

class JourneyTableCellView: NSTableCellView, MergeDelegate {

 
    

    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var thumbnailImageView: NSImageView!
    @IBOutlet weak var noVideosLabel: NSTextField!
    @IBOutlet weak var joinButton: NSButton!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var nameTextField: NSTextField!
    
    
    //    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    var progressTimer: Timer?
    var progressEnding = false
    
    override var objectValue: Any? {
        didSet {
            guard let journey = objectValue as? Journey else { return }
            
            nameLabel.stringValue = journey.getMergedName(resampled: false)
            noVideosLabel.stringValue = "\(journey.videos.count) \(journey.videos.count == 1 ? "clip" : "clips")"
            nameTextField.stringValue = journey.name ?? ""
            progressBar.isHidden = true
            
            Task.init {
                do {
                    let duration = try await journey.getDuration()
                    await MainActor.run { durationLabel.stringValue = "Duration:" + duration.seconds.formattedTimeInterval() }
                } catch let e {
                    await MainActor.run {durationLabel.stringValue = e.localizedDescription }
                }
                
                do {
                    let thumbnail = try await journey.getThumbnail()
                    await MainActor.run {
                        
                        let imageSize = NSSize (width: thumbnail.width, height: thumbnail.height)
                        thumbnailImageView.image = NSImage(cgImage: thumbnail, size: imageSize)
                    }
                    
                } catch {
                    await MainActor.run { thumbnailImageView.image = nil }
                }
            }
        }
    }
    
   
    @IBAction func joinButtonClicked(_ sender: Any) {
       
        guard let journey = objectValue as? Journey else { return }

        if journey.task == nil {
            joinButton.title = "Cancel merge"
            let url = UserDefaults.standard.outputURL
            let name = journey.getMergedName(resampled: false)
            let fileUrlx = URL (fileURLWithPath: name, relativeTo: url)
            let fileUrl = fileUrlx.resolvingSymlinksInPath()
            
            
            journey.task = Task.init {
                do {
                    //              try await journey.merge(intoURL: fileUrl, withPreset: /*AVAssetExportPresetPassthrough*/ AVAssetExportPresetHEVC1920x1080, delegate: self)
                    try await journey.join(intoURL: fileUrl, delegate: self)
                    journey.task = nil
                    await MainActor.run {
                        joinButton.title = "Merge"
                    }
                } catch {
                }
            }
        } else {
            journey.task!.cancel()
        }
    }
    
    func mergeStarted(session: ProgressSource) {
        progressBar.doubleValue = 0
        progressBar.isHidden = false
        progressEnding = false
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] timer in
            if (progressEnding) {
                progressTimer?.invalidate()
                progressBar.isHidden = true
                return
            }
            progressBar.doubleValue = Double (session.progress) * 100
        }
    }
    
    func mergeDone(session: ProgressSource) {
        progressBar.doubleValue = 100
        progressEnding = true
       
    }
    
    @IBAction func nameTextFieldChanged(_ sender: Any) {
        guard let journey = objectValue as? Journey else { return }
        
        let st: String?
        if !nameTextField.stringValue.isEmpty {
            st = nameTextField.stringValue
        } else {
            st = nil
        }
        journey.name = st
        
        nameLabel.stringValue = journey.getMergedName(resampled: false)
    }
    
}
