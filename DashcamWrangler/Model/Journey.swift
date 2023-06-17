//
//  Journey.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation
import AVKit

protocol ProgressSource {
    var progress: Float { get }
    var error: Error? { get }
}

extension AVAssetExportSession: ProgressSource {
}

extension AVAssetExportSessionEx: ProgressSource {
}

protocol ExportSessionDelegate: NSObjectProtocol {
    func mergeDone (session: ProgressSource)
    func mergeStarted (session: ProgressSource)
    var mergeDelegate : MergeDelegate? { get set }
    var progress: Double { get }
}

protocol MergeDelegate: NSObjectProtocol {
    func mergeStart ()
    func mergeProgress (progress: Double)
    func mergeDone ()
}

class Journey {
    let videos : [Video]
    let creationDate: Date

    var task: Task<(), Never>?
    private var exportSessionDelegate: ExportSessionDelegate?
    
    var mergeDelegate: MergeDelegate? {
        didSet { exportSessionDelegate?.mergeDelegate = mergeDelegate }
    }
    
    var mergeProgress: Double? {
        return exportSessionDelegate?.progress
    }
    
    var isMerging: Bool { return exportSessionDelegate != nil }

    var name: String? {
        get {
            guard videos.count > 0 else { return nil }
            let url = URL (fileURLWithPath: videos [0].fileName, relativeTo: videos [0].folderURL)
            return url.getJourneyName()
        }
        
        set {
            guard videos.count > 0, let newValue else { return }
            let url = URL (fileURLWithPath: videos [0].fileName, relativeTo: videos [0].folderURL)
            do {
                try url.setJourneyName(name: newValue)
            } catch {
            }
        }
    }
        
    init (videos: [Video], creationDate: Date) {
        self.videos = videos
        self.creationDate = creationDate
    }
    
    func getThumbnail () async throws -> CGImage {
        return try videos [0].getThumbnail ()
    }
    
    func getDuration () async throws -> CMTime {
        var duration = CMTime.zero
        
        for video in videos {
            let d1 = await video.getDuration()
            
            duration = CMTimeAdd(duration, d1)
        }
        
        return duration
    }
    
    func getMergedName (resampled: Bool) -> String {
        let ext = ".mp4"
        let st : String
        let firstDate = creationDate
        let dateFormatter = DateFormatter ()
        
        if let name {
            dateFormatter.dateFormat = "yyMMdd"
            st = dateFormatter.string(from: firstDate) + " " + name
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            st = dateFormatter.string(from: firstDate) + (resampled ? " Resampled" : " Joined")
        }
       
        return st + ext
    }
    
    enum VideoMergerError : Error {
        case cantCreateComposition
        case noVideoTracks
    }
    
    func getMergedComposition () async throws -> AVComposition {
        let composition = AVMutableComposition ()
         
        guard
            videos.count > 0,
            let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID:kCMPersistentTrackID_Invalid),
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID:kCMPersistentTrackID_Invalid) else {
                throw VideoMergerError.cantCreateComposition
        }
        
        var videoOffset = CMTime.zero
        var audioOffset = CMTime.zero
         
        for video in videos {
             
            if let assetVideoTrack = try await video.getFirstVideoTrack() {
                let videoTimeRange = try await assetVideoTrack.load (.timeRange)
                try compositionVideoTrack.insertTimeRange(videoTimeRange, of: assetVideoTrack, at: videoOffset)
                videoOffset = CMTimeAdd (videoOffset, videoTimeRange.duration)
                 
                if let assetAudioTrack = try await video.getFirstAudioTrack() {
                    let audioTimeRange = try await assetAudioTrack.load (.timeRange)
                    try compositionAudioTrack.insertTimeRange(audioTimeRange, of: assetAudioTrack, at: audioOffset)
                    audioOffset = CMTimeAdd (audioOffset, audioTimeRange.duration)
                }
            }
        }
        return composition
    }
    
    func merge(intoURL url: URL, withPreset presetName: String) async throws {

        let asset = try await getMergedComposition()
        guard let exportSession = AVAssetExportSession (asset: asset, presetName: presetName) else {
            return
        }

        exportSession.outputURL = url
        exportSession.outputFileType = AVFileType.mp4
        
        try? FileManager.default.removeItem(at: url)

        await MainActor.run { exportSessionDelegate?.mergeStarted(session: exportSession) }
        await exportSession.export()
        await MainActor.run { exportSessionDelegate?.mergeDone(session: exportSession) }

    }
    
    func join(intoURL url: URL) async throws {

        let asset = try await getMergedComposition()
        let exportSession = AVAssetExportSessionEx (asset: asset, journey: self)
        
        let width = asset.naturalSize.width
        let height = asset.naturalSize.height
        
        exportSession.outputURL = url
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoSettings = [
            AVVideoCodecKey:AVVideoCodecType.hevc,
            AVVideoWidthKey:width,
            AVVideoHeightKey:height
        ]
        
        try? FileManager.default.removeItem(at: url)
        
        exportSessionDelegate = ExportController ()
        exportSessionDelegate?.mergeDelegate = mergeDelegate
        await MainActor.run { exportSessionDelegate?.mergeStarted(session: exportSession) }
        
        await exportSession.export()
        await MainActor.run { exportSessionDelegate?.mergeDone(session: exportSession) }
        exportSessionDelegate = nil

    }
}
