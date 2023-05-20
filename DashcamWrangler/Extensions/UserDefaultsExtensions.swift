//
//  UserDefaultsExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 04/05/2023.
//

import Foundation
extension UserDefaults {
    private var bookmarkOutputFolderKey: String { return "bookmark"}
    private var customVideoQualityKey: String { return "videoquality.custom"}
    private var customVideoWidthKey: String { return "videoquality.customwidth"}
    private var customVideoHeightKey: String { return "videoquality.customheight"}
    private var customVideoFramerateKey: String { return "videoquality.customframerate"}
    private var customVideoBitrateKey: String { return "videoquality.custombitrate"}

    
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
    
    var customVideo: Bool {
        get {
            return bool(forKey: customVideoQualityKey)
        }
        set {
            set (newValue, forKey: customVideoQualityKey)
        }
    }
    
    func getOptional<T> (forKey key: String) -> T? {
        if let obj = object(forKey: key) {
            return obj as? T
        } else {
            return nil
        }
    }
    
    func setOptional<T> (value: T?, forKey key: String) {
        if let value = value {
            set (value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
    
    var customVideoWidth: CGFloat? {
        get {
            return getOptional(forKey: customVideoWidthKey) as CGFloat?
        } set {
            setOptional(value: newValue, forKey: customVideoWidthKey)
        }
    }
    
    var customVideoHeight: CGFloat? {
        get {
            return getOptional(forKey: customVideoHeightKey) as CGFloat?
        } set {
            setOptional(value: newValue, forKey: customVideoHeightKey)
        }
    }
    
    var customVideoFramerate: CGFloat? {
        get {
            return getOptional(forKey: customVideoFramerateKey) as CGFloat?
        } set {
            setOptional(value: newValue, forKey: customVideoFramerateKey)
        }
    }
    
    var customVideoBitrate: CGFloat? {
        get {
            return getOptional(forKey: customVideoBitrateKey) as CGFloat?
        } set {
            setOptional(value: newValue, forKey: customVideoBitrateKey)
        }
    }
    
    func removeBookmarkKey () {
        removeObject(forKey: bookmarkOutputFolderKey)
    }
    
    func registerDashcamWranglerDefaults () {
        let defaultURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath()
        let bookmarkData = try? defaultURL.bookmarkData(options: .withSecurityScope,  includingResourceValuesForKeys: nil, relativeTo: nil)
        
        if let bookmarkData {
            register(defaults: [
                customVideoWidthKey:Double (1920),
                customVideoFramerateKey:Double (24),
                bookmarkOutputFolderKey: bookmarkData
            ])
        } else {
            register(defaults: [
                customVideoWidthKey:Double (1920),
                customVideoFramerateKey:Double (24)
            ])
        }
    }
}

