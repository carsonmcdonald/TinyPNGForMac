import Cocoa

class FileTableViewController: NSViewController, NSTableViewDataSource {
    
    @IBOutlet weak var filenameTable: NSTableView!
    
    private var tinyPNGWorkflow = TinyPNGWorkflow()
    
    private var filesAddedNotification: NSObjectProtocol?
    
    deinit {
        if self.filesAddedNotification != nil {
            NSNotificationCenter.defaultCenter().removeObserver(self.filesAddedNotification!)
        }
    }
    
    override func viewDidLoad() {
        self.tinyPNGWorkflow.statusUpdate = { (imageProcessingInfo:ImageProcessingInfo) -> Void in
            
            for row in 0...self.tinyPNGWorkflow.getImageCount()-1 {
                if let cell = self.filenameTable.viewAtColumn(0, row: row, makeIfNecessary: false) as? ImageProcessingTableViewCell {
                    
                    if cell.imageProcessingInfo.identifier == imageProcessingInfo.identifier {
                        self.filenameTable.reloadDataForRowIndexes(NSIndexSet(index: row), columnIndexes: NSIndexSet(index: 0))
                        if self.filenameTable.selectedRow == row {
                            NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.FileDetailSelected, object: self, userInfo: ["imageProcessingInfo":imageProcessingInfo])
                        }
                        break
                    }
                    
                }
            }

        }
        
        self.filesAddedNotification = NSNotificationCenter.defaultCenter().addObserverForName(Config.Notification.FileDrop, object: nil, queue: NSOperationQueue.mainQueue()) { (notification:NSNotification!) -> Void in
            
            if notification.userInfo != nil {
                if let fileList = notification.userInfo!["fileList"] as? [String] {
                    for file in fileList {
                        if FileUtils.isDirectory(file) {
                            var nestedFiles = [String]()
                            FileUtils.getNestedPNGFiles(file, files: &nestedFiles)
                            for subFile in nestedFiles {
                                self.tinyPNGWorkflow.queueImageForProcessing(subFile)
                            }
                        } else {
                            self.tinyPNGWorkflow.queueImageForProcessing(file)
                        }
                    }
                    
                    self.filenameTable.reloadData()
                }
            }

        }
        
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.tinyPNGWorkflow.getImageCount()
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeViewWithIdentifier("ImageProcessingTableViewCell", owner: self) as? ImageProcessingTableViewCell {
            cell.imageProcessingInfo = self.tinyPNGWorkflow.getImageProcessingInfoAtIndex(row)
            
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        
        if self.filenameTable.selectedRow >= 0 && self.tinyPNGWorkflow.getImageCount() > self.filenameTable.selectedRow {
            let imageProcessingInfo = self.tinyPNGWorkflow.getImageProcessingInfoAtIndex(self.filenameTable.selectedRow)
            NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.FileDetailSelected, object: self, userInfo: ["imageProcessingInfo":imageProcessingInfo])
        } else {
            NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.FileDetailSelected, object: self, userInfo: nil)
        }
        
    }
    
}
