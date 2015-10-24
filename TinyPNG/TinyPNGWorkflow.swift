import Foundation

enum ImageProcessingStatus {
    case Waiting, Started, Uploading, Downloading, Error, Complete
}

class ImageProcessingInfo {
    var identifier: Int
    var filename: String
    var filePath: NSURL
    var status: ImageProcessingStatus
    var uploadPercent: Double
    var errorMessage: String?
    var downloadURL: NSURL?
    var savingsRatio: Double?
    
    init(identifier:Int, filename:String, filePath:NSURL) {
        self.identifier = identifier
        self.filename = filename
        self.filePath = filePath
        self.status = .Waiting
        self.uploadPercent = 0.0
    }
    
    convenience init(identifier:Int, filename:String, filePath:NSURL, errorMessage:String) {
        self.init(identifier:identifier, filename:filename, filePath:filePath)
        self.errorMessage = errorMessage
        self.status = .Error
    }
}

class TinyPNGWorkflow: NSObject, NSURLSessionTaskDelegate {
    
    var statusUpdate: ((imageProcessingInfo:ImageProcessingInfo) -> Void)?
    
    private var session: NSURLSession!
    private var sessionQueue: NSOperationQueue!
    
    private var imageInfoIndex = 0
    private var imageProcessingInfoList = [ImageProcessingInfo]()
    private let activeTaskToInfoSem = dispatch_semaphore_create(1)
    private var activeTaskToInfo = [NSURLSessionTask:ImageProcessingInfo]()
    
    private let MAX_QUEUED = 10
    
    func queueImageForProcessing(filePath:String) {
        
        self.setupSessionIfNeeded()
        
        imageInfoIndex++
        
        let imageURL = NSURL(fileURLWithPath: filePath)
        if FileUtils.isPNG(imageURL) {
            
            let imageProcessingInfo = ImageProcessingInfo(identifier: imageInfoIndex, filename: (filePath as NSString).lastPathComponent, filePath: imageURL)
            self.imageProcessingInfoList.append(imageProcessingInfo)
            
            if let apiKey = PreferencesManager.getAPIKey() {
                if self.activeTaskToInfo.count < self.MAX_QUEUED {
                    self.startFileUpload(imageProcessingInfo, apiKey: apiKey)
                }
            } else {
                imageProcessingInfo.errorMessage = "Invalid API key."
            }
            
        } else {
            self.imageProcessingInfoList.append(ImageProcessingInfo(identifier: imageInfoIndex, filename: (filePath as NSString).lastPathComponent, filePath: imageURL, errorMessage: "Not a PNG file"))
        }
        
        self.taskCleanup()
        
    }
    
    func getImageCount() -> Int {
        return self.imageProcessingInfoList.count
    }
    
    func getImageProcessingInfoAtIndex(index:Int) -> ImageProcessingInfo {
        return self.imageProcessingInfoList[index]
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        dispatch_semaphore_wait(self.activeTaskToInfoSem, DISPATCH_TIME_FOREVER)
        if let imageProcessingInfo = self.activeTaskToInfo[task] {
            dispatch_semaphore_signal(self.activeTaskToInfoSem)
            if imageProcessingInfo.status == ImageProcessingStatus.Waiting || imageProcessingInfo.status == ImageProcessingStatus.Started {
                imageProcessingInfo.status = .Uploading
                if let cb = self.statusUpdate {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        cb(imageProcessingInfo:imageProcessingInfo)
                    })
                }
            }
            imageProcessingInfo.uploadPercent = Double(totalBytesSent) / Double(totalBytesExpectedToSend) * 100.0
        }

    }
    
    private func startFileUpload(imageProcessingInfo:ImageProcessingInfo, apiKey:String) {
        imageProcessingInfo.status = .Started
        
        if let tinyPNGPostURL = NSURL(string: "https://api.tinypng.com/shrink") {
            let request = self.createAuthedRequest("POST", urlForRequest:tinyPNGPostURL, apiKey: apiKey)

            let task = self.session.uploadTaskWithRequest(request, fromFile: imageProcessingInfo.filePath, completionHandler: { (inputData:NSData?, response:NSURLResponse?, error:NSError?) -> Void in
                
                if let httpResponse = response as? NSHTTPURLResponse, let data = inputData {
                    var errorMessage: String? = nil
                    
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        
                        var parseError: NSError?
                        let parsedObject: AnyObject?
                        do {
                            parsedObject = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
                        } catch let error as NSError {
                            parseError = error
                            parsedObject = nil
                        } catch {
                            fatalError()
                        }
                        
                        if parseError == nil && parsedObject != nil {
                            if let output: AnyObject = parsedObject!["output"] as AnyObject?,
                                let outputURL = output["url"] as? String,
                                let downloadURL = NSURL(string: outputURL),
                                let ratio = output["ratio"] as? Double {
                                    
                                    imageProcessingInfo.downloadURL = downloadURL
                                    imageProcessingInfo.savingsRatio = ratio
                                    
                                    self.startFileDownload(imageProcessingInfo, apiKey: apiKey)
                                    
                            } else {
                                errorMessage = "Could not parse output message"
                            }
                        } else {
                            errorMessage = "Could not parse response message"
                        }
                        
                    } else {
                        if let data = inputData {
                            let errorString = NSString(data: data, encoding: NSUTF8StringEncoding)
                            if errorString != nil && errorString != "" {
                                var parseError: NSError?
                                let parsedObject: AnyObject?
                                do {
                                    parsedObject = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
                                } catch let error as NSError {
                                    parseError = error
                                    parsedObject = nil
                                } catch {
                                    fatalError()
                                }
                                
                                if parseError == nil &&
                                    parsedObject != nil &&
                                    parsedObject!["error"] != nil &&
                                    parsedObject!["message"] != nil {
                                        if let potentialErrorMessage = parsedObject!["message"] as? String {
                                            errorMessage = potentialErrorMessage
                                        }
                                }
                            }
                        }
                        if errorMessage == "" && error != nil {
                            errorMessage = error!.localizedDescription
                        }
                        if errorMessage == "" {
                            errorMessage = "Unknown error"
                        }
                    }
                    
                    if errorMessage != nil {
                        imageProcessingInfo.errorMessage = errorMessage
                        imageProcessingInfo.status = .Error
                        if let cb = self.statusUpdate {
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                cb(imageProcessingInfo:imageProcessingInfo)
                            })
                        }
                    }
                    
                }
                
                self.taskCleanup()
            
            })
            dispatch_semaphore_wait(self.activeTaskToInfoSem, DISPATCH_TIME_FOREVER)
            self.activeTaskToInfo[task] = imageProcessingInfo
            dispatch_semaphore_signal(self.activeTaskToInfoSem)
            task.resume()
        } else {
            imageProcessingInfo.errorMessage = "Could not parse post URL"
            imageProcessingInfo.status = .Error
            if let cb = self.statusUpdate {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    cb(imageProcessingInfo:imageProcessingInfo)
                })
            }
        }
        
    }
    
    private func startFileDownload(imageProcessingInfo:ImageProcessingInfo, apiKey:String) {
        
        imageProcessingInfo.status = .Downloading
        imageProcessingInfo.uploadPercent = 1.0
        if let cb = self.statusUpdate {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                cb(imageProcessingInfo:imageProcessingInfo)
            })
        }
        
        if let downloadURL = imageProcessingInfo.downloadURL {
            let request = self.createAuthedRequest("GET", urlForRequest:downloadURL, apiKey: apiKey)
            
            let task = self.session.downloadTaskWithRequest(request, completionHandler: { (inResultURL:NSURL?, response:NSURLResponse?, error:NSError?) -> Void in
                
                var errorMessage: String? = nil
                if error == nil {
                    if let httpResponse = response as? NSHTTPURLResponse, let resultURL = inResultURL {
                        
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                            
                            var copyError: NSError?
                            let copySuccess: Bool
                            do {
                                try NSFileManager.defaultManager().replaceItemAtURL(imageProcessingInfo.filePath, withItemAtURL: resultURL, backupItemName: nil, options: NSFileManagerItemReplacementOptions(), resultingItemURL: nil)
                                copySuccess = true
                            } catch let error as NSError {
                                copyError = error
                                copySuccess = false
                            } catch {
                                fatalError()
                            }
                            if !copySuccess || copyError != nil {
                                errorMessage = (copyError != nil) ? copyError!.localizedDescription : "Could not overwrite original file"
                            } else {
                                imageProcessingInfo.status = .Complete
                                if let cb = self.statusUpdate {
                                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                        cb(imageProcessingInfo:imageProcessingInfo)
                                    })
                                }
                            }
                            
                        } else {
                            errorMessage = NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode)
                        }
                    } else {
                        errorMessage = "Response was invalid"
                    }
                } else if error != nil {
                    errorMessage = error!.localizedDescription
                }
                
                if errorMessage != nil {
                    imageProcessingInfo.errorMessage = errorMessage
                    imageProcessingInfo.status = .Error
                    if let cb = self.statusUpdate {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            cb(imageProcessingInfo:imageProcessingInfo)
                        })
                    }
                }
                
                self.taskCleanup()
                
            })
            dispatch_semaphore_wait(self.activeTaskToInfoSem, DISPATCH_TIME_FOREVER)
            self.activeTaskToInfo[task] = imageProcessingInfo
            dispatch_semaphore_signal(self.activeTaskToInfoSem)
            task.resume()
        }
        
    }
    
    private func taskCleanup() {
        dispatch_semaphore_wait(self.activeTaskToInfoSem, DISPATCH_TIME_FOREVER)
        for task in self.activeTaskToInfo.keys {
            if task.state == NSURLSessionTaskState.Completed {
                self.activeTaskToInfo.removeValueForKey(task)
            }
        }
        dispatch_semaphore_signal(self.activeTaskToInfoSem)
        for imageProcessingInfo in self.imageProcessingInfoList {
            if imageProcessingInfo.status == .Waiting {
                if self.activeTaskToInfo.count < self.MAX_QUEUED {
                    if let apiKey = PreferencesManager.getAPIKey() {
                        self.startFileUpload(imageProcessingInfo, apiKey: apiKey)
                    }
                }
            }
        }
    }
    
    private func setupSessionIfNeeded() {
        if self.session == nil {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            configuration.timeoutIntervalForRequest = 10
            configuration.HTTPMaximumConnectionsPerHost = PreferencesManager.getMaxConnections()
            
            self.sessionQueue = NSOperationQueue()
            self.sessionQueue.name = "TinyPNG Workflow Queue"
            
            self.session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: self.sessionQueue)
            self.session.sessionDescription = "Session for TinyPNG Workflow"
        }
    }
    
    private func createAuthedRequest(method:String, urlForRequest:NSURL, apiKey:String) -> NSURLRequest {
        let request = NSMutableURLRequest(URL: urlForRequest)
        request.HTTPMethod = method
        
        let authCombo = "api:\(apiKey)"
        let base64Encoded = authCombo.dataUsingEncoding(NSUTF8StringEncoding)
        if let encodedValue = base64Encoded?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions()) {
            request.setValue("Basic \(encodedValue)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
}