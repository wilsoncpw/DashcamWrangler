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
    private let videos: [Video]
        
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
            } // .sorted() { video1, video2 in video1.timestamp < video2.timestamp }
        
        self.videos = videos
    }
    
    typealias VideoTuple = (video: Video, duration: CMTime, timestamp: TimeInterval?)

    func getJourneys() async throws -> [Journey] {
        
        // Create a task group,that will return a sequence of VideoTuples
        await withTaskGroup(of: VideoTuple.self) { group in
            
            // Add a task for each video to get its duration
            for video in videos { group.addTask { await (video, video.getDuration(), video.getCreationDate())} }
            
            // Get all the video/duration tuples.  They won't necessarily be in the original order - so sort them.
            let tuples = await group.reduce(into: [VideoTuple]()) { accum, videoTuple in accum.append(videoTuple)}.sorted() {t1, t2 in t1.video.timestamp < t2.video.timestamp}
            
            var currentJourneyVideos = [Video] ()  // An array for the current journey's videos
            var prevVideoEnd: TimeInterval? = nil       // End of the previous video in milliseconds since 1970
            
            return tuples.reduce(into: [Journey]()) { accum, videoTuple in

                let video = videoTuple.video
                let durationSeconds = videoTuple.duration.seconds
                let timestamp = videoTuple.timestamp ?? video.timestamp
                            
                if let thisPrevVideoEnd = prevVideoEnd {
                    let diff = abs (timestamp - thisPrevVideoEnd)
                    if diff > 5 && currentJourneyVideos.count > 0 {
                        // There were some previous videos before this non-contiguous one.  So make a journey of them...
                        accum.append(Journey (videos: currentJourneyVideos))
                        currentJourneyVideos = [Video]()
                    }
                }
                
                currentJourneyVideos.append(video)
                prevVideoEnd = timestamp + durationSeconds
                
                if video === tuples.last?.video {
                    accum.append(Journey (videos: currentJourneyVideos))
                }
            }
        }
    }
}
