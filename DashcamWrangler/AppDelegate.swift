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

    var contents: Contents? {
        didSet {
            journeyViewController?.contents = contents
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
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
    
    
    func openFolderAtURL (_ url: URL) -> Bool {
        
        guard let contents = try? Contents (folderURL: url) else { return false }
        self.contents = contents
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        return true
    }


}

