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
        
        let _ = NextJourneyNotify.observe { self.selectNext() }
        let _ = PrevJourneyNotify.observe { self.selectPrev() }
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
    
    private func selectNext () {
        if journeysTableView.selectedRow >= journeysTableView.numberOfRows - 1 { return }
        let newRow = journeysTableView.selectedRow + 1
        journeysTableView.selectRowIndexes([newRow], byExtendingSelection: false)
        journeysTableView.scrollRowToVisible(newRow)
        
    }
    
    private func selectPrev () {
        if journeysTableView.selectedRow == 0 { return }
        let newRow = journeysTableView.selectedRow - 1
        journeysTableView.selectRowIndexes([newRow], byExtendingSelection: false)
        journeysTableView.scrollRowToVisible(newRow)
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

extension JourneysViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        guard let journeys = journeys, let table = notification.object as? NSTableView, case let journey = journeys [table.selectedRow] else { return }
        
        JourneySelectedNotify (journey: journey, isFirst: table.selectedRow == 0, isLast: table.selectedRow == table.numberOfRows-1).post()
    }
}
