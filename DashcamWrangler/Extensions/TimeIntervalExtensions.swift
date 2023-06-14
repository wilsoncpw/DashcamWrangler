//
//  TimeIntervalExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Foundation

extension TimeInterval {
    
    //---------------------------------------------------------------------
    /// Get string from TimeInterval
    /// - Returns: Return a TimeInterval as an hh:mm:ss string
    func formattedTimeInterval () ->String {
        let m = (Int (self) / 60) % 60
        let h = (Int (self) / 3600) % 24
        let s = self.truncatingRemainder(dividingBy: 60)
        return String (format: "%02d:%02d:%02.2f", h, m, s)
    }
    
    func since1970ToDate () -> Date {
        return Date(timeIntervalSince1970: self)
    }
}
