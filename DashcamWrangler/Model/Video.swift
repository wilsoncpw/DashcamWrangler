//
//  Video.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation
import AVKit


class Video {
    let folderURL: URL
    let fileName: String

    private lazy var asset = AVAsset (url: folderURL.appendingPathComponent(fileName))
//    lazy var duration = asset.duration
//    lazy var videoTrack = asset.tracks(withMediaType: .video).first
//    lazy var audioTrack = asset.tracks(withMediaType: .audio).first
    lazy var timestamp: TimeInterval = getTimestamp ()
    lazy var creationDate: Date? = getCreationDate ()
    
    init (folderURL: URL, fileName: String) {
        self.folderURL = folderURL
        self.fileName = fileName
    }
    
    private func getTimestamp () -> TimeInterval {
        if let ti = getCreationDate()?.timeIntervalSince1970 {
            return ti
        }
        return 0
    }
    
    private func getCreationDate () -> Date? {
        let formatter = DateFormatter ()
        formatter.dateFormat = "yyyy_MM_dd_HHmmss";
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: folderURL.appendingPathComponent(fileName).path) {
            return attrs [.creationDate] as? Date
        }
        return nil
    }
    
    private func getModifiedDate () -> Date? {
        let formatter = DateFormatter ()
        formatter.dateFormat = "yyyy_MM_dd_HHmmss";
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: folderURL.appendingPathComponent(fileName).path) {
            return attrs [.modificationDate] as? Date
        }
        return nil
    }
    
    func getThumbnail () throws -> CGImage {
        
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        let time = CMTimeMakeWithSeconds(Float64(1), preferredTimescale: 100)
        return try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
    }
    
    func getDuration () async -> CMTime {
        let duration = try? await asset.load(.duration)

        return duration ?? CMTime.zero
    }
    
    func getCreationDate () async -> TimeInterval? {
//        if let dt = try? await asset.load (.creationDate) {
//            let d = try? await dt.load(.dateValue)
//            let dtx = d?.timeIntervalSince1970
//            return dtx
//        }
//        return nil
        
        // This is quite horrid.  With the Garmin, the '.creationDate' isn't accurate at all
        // But the file's modified date seems to be.  So we work out the creation date by
        // subtracting the duration from the modified date.  Ugh!
        
        if let modifiedDate = getModifiedDate() {
            var ts = modifiedDate.timeIntervalSince1970
            ts -= await getDuration().seconds
            return ts
            
        }
        return nil
    }
    
    func getFirstVideoTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .video).first
    }
    
    func getFirstAudioTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .audio).first
    }
}

