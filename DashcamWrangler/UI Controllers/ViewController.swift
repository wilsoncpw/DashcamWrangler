//
//  ViewController.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa

class ViewController: NSViewController {
    
    var asr = false
    var mergeFolderURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.registerDashcamWranglerDefaults()

        if let url = UserDefaults.standard.outputURL {
            asr = url.startAccessingSecurityScopedResource()
            mergeFolderURL = url
        }
    }
    
    override func viewDidDisappear() {
        if asr {
            mergeFolderURL?.stopAccessingSecurityScopedResource()
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

