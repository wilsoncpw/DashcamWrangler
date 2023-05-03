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
    lazy var timestamp: Int64 = getTimestamp ()
    lazy var creationDate: Date? = getCreationDate ()
    
    init (folderURL: URL, fileName: String) {
        self.folderURL = folderURL
        self.fileName = fileName
    }
    
    private func getTimestamp () -> Int64 {
        if let ti = getCreationDate()?.timeIntervalSince1970 {
            return Int64 (ti * 1000)
        }
        return 0
    }
    
    private func getCreationDate () -> Date? {
        let formatter = DateFormatter ()
        formatter.dateFormat = "yyyy_MM_dd_HHmmss";
        
        var fName: String
        if let i = fileName.range(of: ".", options: .backwards)?.lowerBound {
            fName = String (fileName [..<i])
        } else {
            fName = fileName
        }
        
        if fName.starts(with: "VID_") {
            let i = fName.index(fName.startIndex, offsetBy: 4)
            fName = String (fName [i...])
            formatter.dateFormat = "yyyyMMdd_HHmmss"
        }
        
        
        
        // nb.  a TimeInterval is an alias for Double - it contains a number of seconds and
        // may includ a fractional part
        if let ti = formatter.date(from: fName) {
            return ti
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: folderURL.appendingPathComponent(fileName).path) {
            return attrs [.creationDate] as? Date
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
    
    func getFirstVideoTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .video).first
    }
    
    func getFirstAudioTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .audio).first
    }
}

