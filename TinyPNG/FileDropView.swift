import Cocoa

class FileDropView: NSView, NSDraggingDestination {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.registerForDraggedTypes([NSFilenamesPboardType])
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        if let pbTypes = sender.draggingPasteboard().types as? [String] {
            if contains(pbTypes, NSFilenamesPboardType) {
                
                if sender.draggingSourceOperationMask().rawValue & NSDragOperation.Copy.rawValue == 1 {
                    return NSDragOperation.Copy
                }
                
            }
        }
        
        return NSDragOperation.None
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if let pbTypes = sender.draggingPasteboard().types as? [String] {
            if contains(pbTypes, NSFilenamesPboardType) {
                
                if sender.draggingSourceOperationMask().rawValue & NSDragOperation.Copy.rawValue == 1 {
                    if let fileList = sender.draggingPasteboard().propertyListForType(NSFilenamesPboardType) as? [String] {
                        NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.FileDrop, object: self, userInfo: ["fileList":fileList])
                    }
                }
                
            }
        }
        
        return true
    }
    
}
