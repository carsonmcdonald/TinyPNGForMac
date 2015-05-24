import Cocoa

class DetailInfoViewController: NSViewController {
    
    @IBOutlet weak var filenameTextField: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var finalImageView: NSImageView!
    
    private var infoDetailNotification: NSObjectProtocol?
    
    deinit {
        if self.infoDetailNotification != nil {
            NSNotificationCenter.defaultCenter().removeObserver(self.infoDetailNotification!)
        }
    }
    
    override func viewDidLoad() {
        self.infoDetailNotification = NSNotificationCenter.defaultCenter().addObserverForName(Config.Notification.FileDetailSelected, object: nil, queue: NSOperationQueue.mainQueue()) { (notification:NSNotification!) -> Void in
            
            if notification.userInfo != nil {
                if let imageProcessingInfo = notification.userInfo!["imageProcessingInfo"] as? ImageProcessingInfo {
                    self.filenameTextField.stringValue = (imageProcessingInfo.filePath.path == nil) ? "" : imageProcessingInfo.filePath.path!
                    self.statusTextField.stringValue = self.getStringValueFromStatus(imageProcessingInfo)
                    if imageProcessingInfo.status == ImageProcessingStatus.Complete {
                        self.finalImageView.image = NSImage(contentsOfURL: imageProcessingInfo.filePath)
                    }
                }
            } else {
                self.filenameTextField.stringValue = ""
                self.statusTextField.stringValue = ""
                self.finalImageView.image = nil
            }
        }
    }

    private func getStringValueFromStatus(imageProcessingInfo:ImageProcessingInfo) -> String {
        switch imageProcessingInfo.status {
        case .Uploading:
            return String(format:"Uploading: %.2f%%", imageProcessingInfo.uploadPercent)
        case .Downloading:
            return "Downloading"
        case .Error:
            if let errorMessage = imageProcessingInfo.errorMessage {
                return "Error: \(errorMessage)"
            } else {
                return "Error: Unknown error"
            }
        case .Complete:
            return String(format:"Complete: Savings of %.2f%%", imageProcessingInfo.savingsRatio! * 100.0)
        default:
            return "Waiting"
        }
    }
}
