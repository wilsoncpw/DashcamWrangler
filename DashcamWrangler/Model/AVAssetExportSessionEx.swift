//
//  AVAssetExportSessionEx.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 04/05/2023.
//

import Foundation
import AVKit

enum AVAssetExportSessionExError: Error {
    case outputNotSet
    case widthNotSet
    case heightNotSet
}

extension AVAssetExportSessionExError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .outputNotSet: return "Output URL not set"
        case .widthNotSet: return "Width not set"
        case .heightNotSet: return "Height not set"
        }
    }
}

class AVAssetExportSessionEx {
    public var outputURL: URL?
    public var outputFileType : AVFileType? = AVFileType.mp4
    public var timeRange = CMTimeRange (start: .zero, duration: .positiveInfinity)
    public var videoSettings: [String:Any]? = nil
    public var audioSettings: [String:Any]? = nil
    public var framerate : Float?
    
    private  let asset: AVAsset
    private let journey: Journey
    private (set) var error: Error?
    dynamic private (set) var progress : Float = 0
    
    init (asset: AVAsset, journey: Journey) {
        self.asset = asset
        self.journey = journey
    }
    
    public func export() async {

        do {
            guard let outputURL = outputURL, let outputFileType = outputFileType else {
                throw AVAssetExportSessionExError.outputNotSet
            }
            
            let reader = try AVAssetReader (asset: asset)
            let writer = try AVAssetWriter (outputURL: outputURL, fileType: outputFileType)
            
            reader.timeRange = timeRange
            
//            writer.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
            writer.metadata = try await asset.load (.metadata)
            
            let duration: CMTime = CMTIME_IS_VALID(timeRange.duration) && !CMTIME_IS_POSITIVEINFINITY(self.timeRange.duration)
                ? timeRange.duration
                : try await asset.load(.duration)
                        
            var ai: AVAssetWriterInput?
            var ao: AVAssetReaderOutput?
            var vo: AVAssetReaderOutput?
            var vi: AVAssetWriterInput?
            
            try await setupVideoIO(asset: asset, duration: duration, reader: reader, writer: writer, vi: &vi, vo: &vo)
            try await setupAudioIO(asset: asset, duration: duration, reader: reader, writer: writer, ai: &ai, ao: &ao)
            
            let videoInput = vi
            let videoOutput = vo
            
            let audioInput = ai
            let audioOutput = ao
            
            writer.startWriting()
            reader.startReading()
            writer.startSession(atSourceTime: timeRange.start)
            
            let inputQueue = DispatchQueue (label: "VideoEncoderInputQueue")
            
            async let video: Void = withCheckedContinuation { continuation in
                
                if let videoInput, let videoOutput {
                    
                    // requestMediaDataWhenReady is fucking weird.  It continues to call the callback whenever it feels like - until the callback calls  input.markAsFinsihed
                    // We don't know whether the audio or video input will finish first, but we are done when both are complete
                    videoInput.requestMediaDataWhenReady(on: inputQueue) { [self] in
                        
                        if !encodeReadySamplesFromOutput (duration: duration, reader: reader, writer: writer, output: videoOutput, input: videoInput) {
                            continuation.resume() // Video done!
                        }
                    }
                } else { continuation.resume() } // No video
            }
            
            async let audio: Void = withCheckedContinuation { continuation in
                
                if let audioInput, let audioOutput {
                    audioInput.requestMediaDataWhenReady(on: inputQueue) { [self] in
                        if !encodeReadySamplesFromOutput(duration: duration, reader: reader, writer: writer,output: audioOutput, input: audioInput) {
                            continuation.resume() // Audio done!
                        }
                    }
                } else { continuation.resume() } // No audio
            }
            
            let _ = await (video, audio) // Wait for video & audio to complete
            
            if reader.status == .failed { writer.cancelWriting() }
            if writer.status == .failed || writer.status == .cancelled {
                try FileManager.default.removeItem(at: outputURL)
            } else {
                writer.finishWriting {}
            }
        } catch let e {
            self.error = e
        }
    }
    
    private func setupVideoIO (asset: AVAsset, duration: CMTime, reader: AVAssetReader, writer: AVAssetWriter, vi: inout AVAssetWriterInput?, vo: inout AVAssetReaderOutput?) async throws {
        let passthrough = videoSettings == nil
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if videoTracks.count > 0 {
            
            if passthrough {
                vo = AVAssetReaderTrackOutput (track: videoTracks[0], outputSettings: nil)
            } else {
                let videoOutput = AVAssetReaderVideoCompositionOutput (videoTracks: videoTracks, videoSettings: nil)
                
                let videoComposition = try await buildDefaultVideoComposition(videoTrack: videoTracks [0], duration: duration)
                videoOutput.videoComposition = videoComposition
                vo = videoOutput
            }
            
            if let videoOutput = vo {
                videoOutput.alwaysCopiesSampleData = false
                
                if reader.canAdd(videoOutput) {
                    reader.add(videoOutput)
                }
            }
            
            if passthrough {
                let formatDescriptions = try await videoTracks[0].load(.formatDescriptions)
                let vd1 = formatDescriptions[0]
                vi = AVAssetWriterInput (mediaType: .video, outputSettings: nil, sourceFormatHint: vd1)
            } else {
                vi = AVAssetWriterInput (mediaType: .video, outputSettings: videoSettings)
            }
            
            if let videoInput = vi {
                videoInput.expectsMediaDataInRealTime = false
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
            }
        }
    }
    
    private func setupAudioIO (asset: AVAsset, duration: CMTime, reader: AVAssetReader, writer: AVAssetWriter, ai: inout AVAssetWriterInput?, ao: inout AVAssetReaderOutput?) async throws {
        let passthrough = audioSettings == nil
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
         if audioTracks.count > 0 {
             let inputAudioSettings = [
                         AVSampleRateKey: 44100,
                         AVFormatIDKey: kAudioFormatLinearPCM
                     ]
             if passthrough {
                 ao = AVAssetReaderTrackOutput (track: audioTracks [0], outputSettings: inputAudioSettings)
             } else {
                 let audioOutput = AVAssetReaderAudioMixOutput (audioTracks: audioTracks, audioSettings: inputAudioSettings)
                 ao = audioOutput
             }
             
             if let audioOutput = ao {
                 audioOutput.alwaysCopiesSampleData = false
                 if reader.canAdd(audioOutput) {
                     reader.add(audioOutput)
                 }
             }
             
            if passthrough {
                let formatDescriptions = try await audioTracks [0].load(.formatDescriptions)
                let ad1 = formatDescriptions [0]
                ai = AVAssetWriterInput (mediaType: .audio, outputSettings: nil, sourceFormatHint: ad1)
            } else {
                ai = AVAssetWriterInput (mediaType: .audio, outputSettings: audioSettings)
            }
             
            if let audioInput = ai {
                audioInput.expectsMediaDataInRealTime = false
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                }
            }
         }
    }

    
    private func encodeReadySamplesFromOutput (duration: CMTime, reader: AVAssetReader, writer: AVAssetWriter, output: AVAssetReaderOutput, input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            guard let sampleBuffer = output.copyNextSampleBuffer(), !(journey.task?.isCancelled ?? true) else {
                input.markAsFinished()
                return false
            }
            
            if reader.status != .reading || writer.status != .writing {
                if let e = writer.error {
                    print (e.localizedDescription)
                }
                return false
            }
                        
            if input.mediaType == .video {
                var lastSamplePresentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                lastSamplePresentationTime = CMTimeSubtract(lastSamplePresentationTime, timeRange.start)
                let seconds = CMTimeGetSeconds(lastSamplePresentationTime)
                let durationSeconds = CMTimeGetSeconds(duration)
                progress = durationSeconds == 0 ? 1 : Float (seconds / durationSeconds)
            }
            
            if !input.append(sampleBuffer) {
                if let e = writer.error {
                    print (e.localizedDescription)
                }
                return false
            }
        }
        return true
    }
    
    private func buildDefaultVideoComposition (videoTrack: AVAssetTrack, duration: CMTime) async throws -> AVMutableVideoComposition {
        
        let videoComposition = AVMutableVideoComposition ()
        
        let  trackFrameRate: Float
        if let framerate {
            trackFrameRate = framerate
        } else {
            trackFrameRate = try await videoTrack.load(.nominalFrameRate)
        }
        
        var _targetSize = CGSize.zero
        if let videoSettings = videoSettings {
            
            if let targetWidth = videoSettings [AVVideoWidthKey] as? NSNumber {
                _targetSize.width = CGFloat (targetWidth.floatValue)
            }
            if let targetHeight = videoSettings [AVVideoHeightKey] as? NSNumber {
                _targetSize.height = CGFloat (targetHeight.floatValue)
            }
        }
        
        videoComposition.frameDuration = CMTimeMake (value: 1, timescale: Int32(trackFrameRate))
        let targetSize = _targetSize
        var naturalSize = try await videoTrack.load (.naturalSize)
        
        var _transform = try await videoTrack.load(.preferredTransform)
        if _transform.ty == -560 { _transform.ty = 0}
        if _transform.tx == -560 { _transform.ty = 0 }
        
        let videoAngleInDegree = atan2(_transform.b, _transform.a) * 180 / CGFloat.pi
        if videoAngleInDegree == 90 || videoAngleInDegree == -90 {
            let width = naturalSize.width
            naturalSize.width = naturalSize.height
            naturalSize.height = width
        }
        videoComposition.renderSize = naturalSize
        let xratio = targetSize.width / naturalSize.width
        let yratio = targetSize.height / naturalSize.height
        let ratio = min (xratio, yratio)
        
        let postWidth = naturalSize.width * ratio
        let postHeigt = naturalSize.height * ratio
        let transx = (targetSize.width - postWidth) / 2
        let transy = (targetSize.height - postHeigt) / 2
        
        let matrix = CGAffineTransform (translationX: transx/xratio, y: transy/yratio).scaledBy(x: ratio/xratio, y: ratio/yratio)
        _transform = _transform.concatenating(matrix)
        let transform = _transform
        
        let passThroughInstruction = AVMutableVideoCompositionInstruction ()
        passThroughInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: duration)
        
        let passThroughLayer = AVMutableVideoCompositionLayerInstruction (assetTrack: videoTrack)
        passThroughLayer.setTransform(transform, at: .zero)
        
        passThroughInstruction.layerInstructions = [passThroughLayer]
        videoComposition.instructions = [passThroughInstruction]
        
        return videoComposition
    }
 
}
