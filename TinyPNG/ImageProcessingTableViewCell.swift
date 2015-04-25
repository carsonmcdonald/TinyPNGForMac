import Cocoa

class ImageProcessingTableViewCell: NSTableCellView {
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var imageFilenameLabel: NSTextField!
    @IBOutlet weak var statusImageView: NSImageView!
    
    var imageProcessingInfo: ImageProcessingInfo! {
        didSet {
            self.imageFilenameLabel.stringValue = self.imageProcessingInfo.filename
            self.handleStatusValue(self.imageProcessingInfo.status)
        }
    }
    
    private func handleStatusValue(status:ImageProcessingStatus) {
        switch status {
        case .Uploading:
            self.statusImageView.hidden = true
            self.progressIndicator.hidden = false
            self.progressIndicator.startAnimation(self)
        case .Downloading:
            self.statusImageView.hidden = true
            self.progressIndicator.hidden = false
            self.progressIndicator.startAnimation(self)
        case .Error:
            self.statusImageView.hidden = false
            self.progressIndicator.hidden = true
            self.progressIndicator.stopAnimation(self)
            self.statusImageView.image = NSImage(named: "ic_error_red")
        case .Complete:
            self.statusImageView.hidden = false
            self.progressIndicator.hidden = true
            self.progressIndicator.stopAnimation(self)
            self.statusImageView.image = NSImage(named: "ic_check_black")
        default:
            self.statusImageView.hidden = false
            self.progressIndicator.hidden = true
            self.progressIndicator.stopAnimation(self)
            self.statusImageView.image = NSImage(named: "ic_more_horiz")
        }
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            let textColor = (backgroundStyle == .Dark) ? NSColor.windowBackgroundColor() : NSColor.blackColor()
            for subview in self.subviews {
                if let label = subview as? NSTextField {
                    label.textColor = textColor
                }
            }
        }
    }
    
}
