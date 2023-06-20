//
//  UserDefaultsExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 04/05/2023.
//

import Foundation
extension UserDefaults {
    private var bookmarkOutputFolderKey: String { return "bookmark"}                        // Holds bookmark data for output URL
    private var customVideoQualityKey: String { return "videoquality.custom"}               // Holds boolean - custom output or not
    private var customVideoWidthKey: String { return "videoquality.customwidth"}            // Optional - holds custom video width CGFloat
    private var customVideoHeightKey: String { return "videoquality.customheight"}          // Optional - holds custom video height CGFloat
    private var customVideoFramerateKey: String { return "videoquality.customframerate"}    // Optional - holds custom framerate CGFloat
    private var customVideoBitrateKey: String { return "videoquality.custombitrate"}        // Optional - holds custom bitrate CGFloat
    
    //---------------------------------------------------------------------
    /// The current output URL - saved as a bookmarkk
    var outputURL: URL? {
        get {
            if let bookmarkData = object(forKey: bookmarkOutputFolderKey) as? Data {
                var isStale = false
                if let url = try? URL.init(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    return url
                }
            }
            return nil
        }
        set {
            if let newURL = newValue, let bookmark = try? newURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                set(bookmark, forKey: bookmarkOutputFolderKey)
            } else {
                removeObject(forKey: bookmarkOutputFolderKey)
            }
        }
    }
    
    //---------------------------------------------------------------------
    /// Whether to use custom video settings
    var customVideo: Bool {
        get {
            return bool(forKey: customVideoQualityKey)
        }
        set {
            set (newValue, forKey: customVideoQualityKey)
        }
    }
    
    //---------------------------------------------------------------------
    /// Get optional value for key of type T
    /// - Parameter key: The value key
    /// - Returns: The value
    func getOptional<T> (forKey key: String) -> T? {
        return object(forKey:key) as? T
    }
    
    //---------------------------------------------------------------------
    /// Set optinal value of type T for key - or remove it iif it's nil
    /// - Parameters:
    ///   - value: The value of type T
    ///   - key: The key
    func setOptional<T> (value: T?, forKey key: String) {
        if let value {
            set (value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
        
    //---------------------------------------------------------------------
    /// Optional custom video width
    var customVideoWidth: CGFloat? {
        get { getOptional(forKey: customVideoWidthKey) }
        set { setOptional(value: newValue, forKey: customVideoWidthKey) }
    }
    
    //---------------------------------------------------------------------
    /// Optional custtom video height
    var customVideoHeight: CGFloat? {
        get { getOptional(forKey: customVideoHeightKey) }
        set { setOptional(value: newValue, forKey: customVideoHeightKey) }
    }
    
    //---------------------------------------------------------------------
    /// Optional custom video framerate
    var customVideoFramerate: CGFloat? {
        get { getOptional(forKey: customVideoFramerateKey) }
        set { setOptional(value: newValue, forKey: customVideoFramerateKey) }
    }
    
    //---------------------------------------------------------------------
    /// Optional custom video bitrate
    var customVideoBitrate: CGFloat? {
        get { getOptional(forKey: customVideoBitrateKey) }
        set { setOptional(value: newValue, forKey: customVideoBitrateKey) }
    }
    
    func registerDashcamWranglerDefaults () {
        var defaults: [String: Any] = [customVideoWidthKey:CGFloat (1920), customVideoFramerateKey:CGFloat(24)]
        
        let defaultURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath()
        if let bookmarkData = try? defaultURL.bookmarkData(options: .withSecurityScope,  includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults [bookmarkOutputFolderKey] = bookmarkData
        }
        
        register(defaults: defaults)
    }
}

