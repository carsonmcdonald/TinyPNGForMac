import Foundation

class FileUtils: NSObject {
    
    class func getNestedPNGFiles(directoryName:String, inout files:[String]) {
        var fileEnumerator = NSFileManager.defaultManager().enumeratorAtPath(directoryName)
        while let file = fileEnumerator?.nextObject() as? String {
            if self.isDirectory(file) {
                self.getNestedPNGFiles(file, files: &files)
            } else {
                let fullPath = directoryName.stringByAppendingPathComponent(file)
                if let fullPathURL = NSURL(string: "file://\(fullPath)") {
                    if self.isPNG(fullPathURL) {
                        files.append(fullPath)
                    }
                }
            }
        }
    }
    
    class func isDirectory(directoryName:String) -> Bool {
        var directoryFlagP = UnsafeMutablePointer<ObjCBool>.alloc(1)
        var directoryFlag:Bool = false
        
        if NSFileManager.defaultManager().fileExistsAtPath(directoryName, isDirectory: directoryFlagP) {
            directoryFlag = directoryFlagP.memory.boolValue
        }
        
        directoryFlagP.dealloc(1)
        return directoryFlag
    }
    
    class func isPNG(imageURL:NSURL) -> Bool {
        
        if let imageSource = CGImageSourceCreateWithURL(imageURL, nil),
            let imageType = CGImageSourceGetType(imageSource) {
                
                if imageType == kUTTypePNG {
                    return true
                }
                
        }
        
        return false
    }
    
}
