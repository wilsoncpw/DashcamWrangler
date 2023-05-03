//
//  JourneyTableCellView.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa

class JourneyTableCellView: NSTableCellView {

    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var thumbnailImageView: NSImageView!
    @IBOutlet weak var noVideosLabel: NSTextField!
    
    
    //    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    override var objectValue: Any? {
        didSet {
            guard let journey = objectValue as? Journey else { return }
            
            nameLabel.stringValue = journey.getMergedName(resampled: false)
            noVideosLabel.stringValue = "\(journey.videos.count) \(journey.videos.count == 1 ? "clip" : "clips")"
            
            Task.init {
                do {
                    let duration = try await journey.getDuration()
                    await MainActor.run { durationLabel.stringValue = duration.seconds.formattedTimeInterval() }
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
    
}
