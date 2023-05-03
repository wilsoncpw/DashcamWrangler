//
//  Journey.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation
import AVKit

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
}
