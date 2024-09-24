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

protocol MergeDelegate: NSObjectProtocol {
    func mergeStart ()
    func mergeProgress (progress: Double)
    func mergeDone ()
}


//=====================================================================================
/// Journey class
class Journey {
    let videos : [Video]
    let creationDate: Date
 
    private var exportController: ExportController?
    
    var mergeDelegate: MergeDelegate? {
        didSet { exportController?.mergeDelegate = mergeDelegate }
    }
    
    var mergeProgress: Double? { return exportController?.progress }
    var isMerging: Bool { return exportController != nil }
    
    /// The journey name
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
    
    //---------------------------------------------------------------------------------
    /// Init
    /// - Parameters:
    ///   - videos: The journey videos
    ///   - creationDate: The creation date
    init (videos: [Video], creationDate: Date) {
        self.videos = videos
        self.creationDate = creationDate
    }
    
    //---------------------------------------------------------------------------------
   /// getThumbnail
    /// - Returns: The thumbnail
    func getThumbnail () async throws -> CGImage {
        return try videos [0].getThumbnail ()
    }
    
    //---------------------------------------------------------------------------------
    /// getDuration bu adding each video's duration value
    /// - Returns: The journey duration
    func getDuration () async throws -> CMTime {
        var duration = CMTime.zero
        
        for video in videos {
            let d1 = await video.getDuration()
            
            duration = CMTimeAdd(duration, d1)
        }
        
        return duration
    }
    
    //---------------------------------------------------------------------------------
    /// getMergedName
    /// - Returns: The file name of the merged journey
    func getMergedName (isSnippet: Bool = false) -> String {
        let ext = ".mp4"
        var st : String
        let firstDate = creationDate
        let dateFormatter = DateFormatter ()
        
        if let name {
            dateFormatter.dateFormat = "yyMMdd"
            st = dateFormatter.string(from: firstDate) + " " + name
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            st = dateFormatter.string(from: firstDate) + " Joined"
        }
        
        if isSnippet {
            st += " Snippet"
        }
       
        return st + ext
    }
    
    enum VideoMergerError : Error {
        case cantCreateComposition
        case noVideoTracks
    }
    
    //---------------------------------------------------------------------------------
    /// getMergedComposition
    /// - Returns: AVComposition of all the videos in the journey
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
    
    //---------------------------------------------------------------------------------
    /// Join - Create merged composition & export it to the URL - resampled to hevc format
    /// - Parameter url: The URL to export to
    func join(intoURL url: URL, task: Task<Void, Never>, timeRange: CMTimeRange? = nil) async throws {

        let asset = try await getMergedComposition()
        let exportSession = AVAssetExportSessionEx (asset: asset, journey: self, task: task)
        
        let width = asset.naturalSize.width
        let height = asset.naturalSize.height
        
        exportSession.outputURL = url
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoSettings = [
            AVVideoCodecKey:AVVideoCodecType.hevc,
            AVVideoWidthKey:width,
            AVVideoHeightKey:height
        ]
        
        if let timeRange {
            exportSession.timeRange = timeRange
        }
        
        
        // Remove previpus file with the same name
        try? FileManager.default.removeItem(at: url)
        
        // Create an export controller to handle progress on the mergeDelegate
        exportController = ExportController ()
        exportController?.mergeDelegate = mergeDelegate
        await MainActor.run { exportController?.mergeStarted(session: exportSession) }
        
        await exportSession.export()
        await MainActor.run { exportController?.mergeDone(session: exportSession) }
        exportController = nil

    }
}
