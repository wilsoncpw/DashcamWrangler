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
    lazy var timestampSince1970: TimeInterval = getTimestampSince1970 ()
    
    init (folderURL: URL, fileName: String) {
        self.folderURL = folderURL
        self.fileName = fileName
    }
    
    private func getTimestampSince1970 () -> TimeInterval {
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
    
    enum BadFile: Error {
        case noModifiedDate
    }
    
    private func getModifiedDate () -> Date {
        let formatter = DateFormatter ()
        formatter.dateFormat = "yyyy_MM_dd_HHmmss";
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: folderURL.appendingPathComponent(fileName).path) {
            guard let rv = attrs [.modificationDate] as? Date else { return Date.distantPast }
            return rv
        }
        return Date.distantPast
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
    
    func getTimeIntervalSince1970 () async -> TimeInterval {
        let modifiedDate = getModifiedDate()
        var ts = modifiedDate.timeIntervalSince1970
        ts -= await getDuration().seconds
        return ts
    }
    
    func getFirstVideoTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .video).first
    }
    
    func getFirstAudioTrack () async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: .audio).first
    }
    
    func deleteSourceFile (includeLocked: Bool) throws {
        let fileManager = FileManager.default
        let path = folderURL.appendingPathComponent(fileName).path
        
        if includeLocked {
            try fileManager.setAttributes([.immutable : NSNumber (0)], ofItemAtPath: path)
        }
        
        try fileManager.removeItem(atPath: path)
    }
}

