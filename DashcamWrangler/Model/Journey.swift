//
//  Journey.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation
import AVKit

protocol MergeDelegate: NSObjectProtocol {
    func mergeDone (session: Any, error: Error?)
    func mergeProgress (session: Any, progress: Float)
}

class Journey {
    let videos : [Video]
//    lazy var duration:CMTime = videos.reduce(into: CMTime.zero) {accum, video in
//        accum = CMTimeAdd (accum, video.duration)
//    }
 //   var cachedThumbnail: CachedThumbnail?
        
    init (videos: [Video]) {
        self.videos = videos
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
        var st = ""
        if let firstDate = videos [0].creationDate {
            let dateFormatter = DateFormatter ()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            st = dateFormatter.string(from: firstDate) + " "
        }
        
        if resampled {
            st += "Resampled.mp4"
        } else {
            st += "Joined.mp4"
        }
        return st
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
    
    func merge(intoURL url: URL, withPreset presetName: String, delegate: MergeDelegate?) async throws {

        let asset = try await getMergedComposition()
        guard let exportSession = AVAssetExportSession (asset: asset, presetName: presetName) else {
            return
        }

        exportSession.outputURL = url
        exportSession.outputFileType = AVFileType.mp4
        
        try? FileManager.default.removeItem(at: url)

        let progresTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            delegate?.mergeProgress(session: exportSession, progress: exportSession.progress)
        }
        
        await exportSession.export()
        
        progresTimer.invalidate()
        delegate?.mergeDone(session: exportSession, error: exportSession.error)
          
    }
}
