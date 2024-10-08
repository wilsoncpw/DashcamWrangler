//
//  AppDelegate.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var journeyViewController: JourneysViewController?
    var videoViewController: VideoViewController?
    @IBOutlet weak var setRangeStartMenuItem: NSMenuItem!
    @IBOutlet weak var setRangeEndMenuItem: NSMenuItem!
    @IBOutlet weak var saveSnippetMenuItem: NSMenuItem!
    
    var contents: Contents? {
        didSet {
            journeyViewController?.contents = contents
        }
    }
    
    var currentJourney: Journey? {
        didSet {
            setRangeStartMenuItem.isEnabled = currentJourney != nil
            setRangeEndMenuItem.isEnabled = currentJourney != nil
            saveSnippetMenuItem.isEnabled = false
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    //----------------------------------------------------------------------
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return openFolderAtURL(URL (fileURLWithPath: filename))
    }
    
    //----------------------------------------------------------------------
    @IBAction func openDocument (_ sender: AnyObject) {
        let openPanel = NSOpenPanel ()
        
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.resolvesAliases = true
        
        if openPanel.runModal()  == .OK {
            if let url = openPanel.url {
                let _ = openFolderAtURL(url)
            }
        }
    }
    
    func updateHasSnippet () {
        saveSnippetMenuItem.isEnabled = videoViewController?.rangeStartTime != nil && videoViewController?.rangeEndTime != nil
    }
    
    @IBAction func setRangeStart (_ sender: AnyObject) {
        videoViewController?.setRangeStart()
    }
    
    @IBAction func setRangeEnd (_ sender: AnyObject) {
        videoViewController?.setRangeEnd()
    }
    
    @IBAction func saveSnippet(_ sender: Any) {
        videoViewController?.saveSnippet()
    }
    
    func openFolderAtURL (_ url: URL) -> Bool {
        
        guard let contents = try? Contents (folderURL: url) else { return false }
        self.contents = contents
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        return true
    }
    
 


}

