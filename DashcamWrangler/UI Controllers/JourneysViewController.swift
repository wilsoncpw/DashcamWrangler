//
//  JourneysViewController.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa

class JourneysViewController: NSViewController {

    @IBOutlet weak var journeysTableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.journeyViewController = self
        }
    }
    
    var journeys: [Journey]? {
        didSet {
            journeysTableView.reloadData()
        }
    }
    
    var contents: Contents? {
        didSet {
            guard let contents else { journeys = nil; return }
            Task.init {
                do {
                    let journeys = try await contents.getJourneys()
                    await MainActor.run { self.journeys = journeys }
                } catch  {
                    journeys = nil
                }
            }
        }
    }
}

extension JourneysViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return journeys?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return journeys? [row]
    }
}
