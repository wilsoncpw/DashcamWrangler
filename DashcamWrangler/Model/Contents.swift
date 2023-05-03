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
//    let journeys: [Journey]
    private let videos: [Video]
    
//    private let filenameMap: [String:Int]
    
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

    
    func getJourneysEx() async throws -> [Journey] {
        var journeyVideos = [Video] () // a temporary array for the current journey's videos
        var journeys = [Journey]()
        var prevVideoEnd: Int64?
        
        let sortedVideos = videos.sorted() { video1, video2 in video1.timestamp < video2.timestamp }
        for video in sortedVideos {
            var needsNewJourney = true
            let duration = await video.getDuration()

            if let thisPrevVideoEnd = prevVideoEnd {
                let videoTimestamp = video.timestamp
               
                if abs (videoTimestamp - thisPrevVideoEnd) < 5000 {
                    needsNewJourney = false
                }
            }
            
            if needsNewJourney {
                if journeyVideos.count > 0 {
                    journeys.append(Journey(videos: journeyVideos))
                    journeyVideos.removeAll()
                }
            }
            journeyVideos.append(video)
            prevVideoEnd = video.timestamp + Int64 (duration.seconds * 1000)
            
            if (video === sortedVideos.last) {
                journeys.append(Journey(videos: journeyVideos))
            }
        }
        
        return journeys
    }
    
    typealias VideoTuple = (video: Video, duration: CMTime)

    func getJourneys() async throws -> [Journey] {
        
        // Create a task group,that will return a sequence of VideoTuples
        await withTaskGroup(of: VideoTuple.self) { group in
            
            // Add a task for each video to get its duration
            for video in videos { group.addTask { await (video, video.getDuration())} }
            
            // Get all the video/duration tuples.  They won't necessarily be in the original order - so sort them.
            let tuples = await group.reduce(into: [VideoTuple]()) { accum, videoTuple in accum.append(videoTuple)}.sorted() {t1, t2 in t1.video.timestamp < t2.video.timestamp}
            
            var currentJourneyVideos = [Video] ()  // An array for the current journey's videos
            var prevVideoEnd: Int64?        // End of the previous video in milliseconds since 1970
            
            return tuples.reduce(into: [Journey]()) { accum, videoTuple in

                let video = videoTuple.video
                let duration = videoTuple.duration
                      
                if let thisPrevVideoEnd = prevVideoEnd, abs (video.timestamp - thisPrevVideoEnd) < 5000 {} else {
                    if currentJourneyVideos.count > 0 {
                        // There were some previous videos before this non-contiguous one.  So make a journey of them...
                        accum.append(Journey (videos: currentJourneyVideos))
                        currentJourneyVideos = [Video]()
                    }
                }
                
                currentJourneyVideos.append(video)
                prevVideoEnd = video.timestamp + Int64 (duration.seconds * 1000)
                
                if video === tuples.last?.video {
                    accum.append(Journey (videos: currentJourneyVideos))
                }
            }
        }
    }
}
