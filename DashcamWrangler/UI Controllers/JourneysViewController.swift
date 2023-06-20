//
//  JourneysViewController.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 02/05/2023.
//

import Cocoa

class JourneysViewController: NSViewController {

    @IBOutlet weak var journeysTableView: NSTableView!
    @IBOutlet weak var outputFolderLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.journeyViewController = self
        }
        
        let _ = NextJourneyNotify.observe { self.selectNext() }
        let _ = PrevJourneyNotify.observe { self.selectPrev() }
        let _ = DeleteJourneyNotify.observe { journey in self.deleteJourney (journey) }
    }
    
    override func viewDidAppear() {
        showOutputFolder()
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
    
    private func showOutputFolder () {
        
        guard let url = UserDefaults.standard.outputURL, url.isFileURL else {
            outputFolderLabel.stringValue = "-"
            outputFolderLabel.toolTip = "Not set"
            return
        }
        
        let path = url.standardizedFileURL.path(percentEncoded: false)
        
        let st = FileManager.default.displayName(atPath: path)
                
        outputFolderLabel.stringValue = st
        outputFolderLabel.toolTip = path
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
        
    private func deleteJourney (_ journey: Journey) {
        guard let contents else { return }
        
        do {
            do {
                try contents.deleteVideoFilesForJourney(journey, includeLocked: false)
            } catch CocoaError.fileWriteNoPermission {
                let alert = NSAlert()
                alert.messageText = "Warning"
                alert.informativeText = "Some of the video files in the journey are locked"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Delete anyway").hasDestructiveAction = true
                
                switch alert.runModal() {
                case .alertSecondButtonReturn:
                    try? contents.deleteVideoFilesForJourney(journey, includeLocked: true)
                default: throw CocoaError (.fileWriteNoPermission)
                }
            }
            journeys?.removeAll(where:) { arrayJourney in arrayJourney === journey }
            journeysTableView.reloadData()
        }
        catch let e {
            print (e)
        }
    }
    
    @IBAction func outputFolderButtonClicked(_ sender: Any) {
        let openPanel = NSOpenPanel ()
        
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.resolvesAliases = true
        openPanel.directoryURL = UserDefaults.standard.outputURL
        
        if openPanel.runModal()  == .OK {
            if let url = openPanel.url {
                UserDefaults.standard.outputURL = url
                showOutputFolder()
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

extension JourneysViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        guard let journeys = journeys, let table = notification.object as? NSTableView, case let journey = journeys [table.selectedRow] else { return }
        
        JourneySelectedNotify (journey: journey, isFirst: table.selectedRow == 0, isLast: table.selectedRow == table.numberOfRows-1).post()
    }
}
