//
//  ExportController.swift
//  Dashcam Wrangler
//
//  Created by Colin Wilson on 17/06/2023.
//

import Foundation

class ExportController: NSObject {
    
    var mergeDelegate: MergeDelegate?
    private(set) var progress: Double = 0
    private var progressEnding = false
    private var progressTimer: Timer?
    
    func mergeStarted(session: ProgressSource) {
        progress = 0
        progressEnding = false
        mergeDelegate?.mergeStart()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] timer in
            if (progressEnding) {
                progressTimer?.invalidate()
                mergeDelegate?.mergeDone()
                return
            }
            progress = Double (session.progress) * 100
            mergeDelegate?.mergeProgress(progress: progress)
        }
    }
    
    func mergeDone(session: ProgressSource) {
        progress = 100
        progressEnding = true
       
    }
}
