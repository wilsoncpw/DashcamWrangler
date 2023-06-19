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
    
    override var objectValue: Any? {
        didSet {
            guard let journey = objectValue as? Journey else { return }
            
            journey.mergeDelegate = self
            
            nameLabel.stringValue = journey.getMergedName(resampled: false)
            noVideosLabel.stringValue = "\(journey.videos.count) \(journey.videos.count == 1 ? "clip" : "clips")"
            nameTextField.stringValue = journey.name ?? ""
            
            setProgessDetails()
            
            if let mergeProgress = journey.mergeProgress {
                progressBar.doubleValue = mergeProgress
            }
            
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
            let url = UserDefaults.standard.outputURL
            let name = journey.getMergedName(resampled: false)
            let fileUrlx = URL (fileURLWithPath: name, relativeTo: url)
            let fileUrl = fileUrlx.resolvingSymlinksInPath()
            
            
            journey.task = Task.init {
                do {
                    //              try await journey.merge(intoURL: fileUrl, withPreset: /*AVAssetExportPresetPassthrough*/ AVAssetExportPresetHEVC1920x1080, delegate: self)
                    try await journey.join(intoURL: fileUrl)
                    journey.task = nil
                } catch {
                }
            }
        } else {
            journey.task!.cancel()
        }
    }
    
    @IBAction func deleteButtonClicked(_ sender: Any) {
        guard let journey = objectValue as? Journey else { return }
        DeleteJourneyNotify(journey: journey).post()
    }
    
    func setProgessDetails () {
        guard let journey = objectValue as? Journey else { return }
        
        if journey.isMerging {
            progressBar.isHidden = false
            joinButton.title = "Cancel merge"
            
        } else {
            progressBar.isHidden = true
            joinButton.title = "Merge"
        }

    }
    
    func mergeStart() {
        progressBar.doubleValue = 0
        setProgessDetails()
    }
    
    func mergeProgress(progress: Double) {
        progressBar.doubleValue = progress
    }
    
    func mergeDone() {
        setProgessDetails()
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
