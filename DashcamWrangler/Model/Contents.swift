//
//  Contents.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation
import AVKit

//=====================================================================================
/// Contents class
///
/// Contains an array of Journeys, each holding an array of contiguous videos
class Contents {
    let folderURL: URL
    private var videos: [Video]
        
    //---------------------------------------------------------------------------------
    /// Initialize from a folder URL.
    ///
    /// Builds the Journeys array from the videos in the given URL
    ///
    /// - Parameter folderURL: The folder URL
    /// - Throws: File manager errors - if for instance the folder URL is invalid
    init (folderURL: URL) throws {
        
        self.folderURL = folderURL
        let fileTypes = Set<String> (["m4v", "mov", "mp4", "hevc", "avi"])
        
        // Create an array of videos from the content - sorted by the video timestamp
        let videos = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.nameKey], options: .skipsHiddenFiles)
            .reduce(into: [Video] ()) {
                videos, url in
                let ext = url.pathExtension
                let fileName = url.lastPathComponent
                let ok = fileTypes.contains(ext.lowercased()) && !fileName.hasSuffix("_s." + ext)
                if ok {
                    videos.append(Video (folderURL: folderURL, fileName: url.lastPathComponent))
                }
            }
        
        self.videos = videos
    }
    
    typealias VideoTuple = (video: Video, duration: CMTime, timestamp: TimeInterval)
    
    //---------------------------------------------------------------------------------
    /// Transform the amorphous array of videos into journeys and their contiguous videos
    /// - Returns: Return an array of journeys from the content's videos.
    func getJourneys() async throws -> [Journey] {
        
        guard videos.count > 0 else { return [] }
        
        // Create a task group,that will return a sequence of VideoTuples
        return await withTaskGroup(of: VideoTuple.self) { group in
            
            // Add a task for each video to get its duration and creationdate
            for video in videos { group.addTask { await (video, video.getDuration(), video.getTimeIntervalSince1970 ())} }
            
            // Get all the video/duration tuples.  They won't necessarily be in the original order - so sort them.
            let tuples = await group.reduce(into: [VideoTuple]()) { accum, videoTuple in
                accum.append(videoTuple)
            }.sorted() { t1, t2 in t1.timestamp < t2.timestamp }
                        
            var currentJourneyVideos = [Video] ()           // An array for the current journey's videos
            var prevVideoEnd: TimeInterval? = nil           // End of the previous video in milliseconds since 1970
            var firstJourneyVideo: VideoTuple = tuples [0]  // The first video in the current journey
            
            var journies = tuples.reduce(into: [Journey]()) { accum, videoTuple in
                let video = videoTuple.video

                guard case let durationSeconds = videoTuple.duration.seconds, durationSeconds > 0 else { return }
                guard case let timestamp = videoTuple.timestamp, timestamp.since1970ToDate() != .distantPast else { return }
                
                if let thisPrevVideoEnd = prevVideoEnd {
                    let diff = abs (timestamp - thisPrevVideoEnd)
                    if diff > 5 && currentJourneyVideos.count > 0 {
                        // There were some previous videos before this non-contiguous one.  So make a journey of them...
                        accum.append(Journey (videos: currentJourneyVideos, creationDate: firstJourneyVideo.timestamp.since1970ToDate()))
                        firstJourneyVideo = videoTuple
                        currentJourneyVideos = [Video]()
                    }
                }
                
                currentJourneyVideos.append(video)
                prevVideoEnd = timestamp + durationSeconds
            }
            
            // Append journey of trailing contiguous videos
            if currentJourneyVideos.count > 0 {
                journies.append(Journey (videos: currentJourneyVideos, creationDate: firstJourneyVideo.timestamp.since1970ToDate()))
            }
            
            return journies
        }
    }
    
    func deleteVideoFilesForJourney (_ journey: Journey, includeLocked: Bool) throws {
        
        try journey.videos.forEach { video in
            try video.deleteSourceFile (includeLocked: includeLocked)
            videos.removeAll(where: ) { arrayVid in arrayVid === video }
        }
    }
}
