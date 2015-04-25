import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet weak var apiKeyTextField: NSTextField!
    @IBOutlet weak var maxConcurrentRequests: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.maxConcurrentRequests.stringValue = "\(PreferencesManager.getMaxConnections())"
        if let apiKey = PreferencesManager.getAPIKey() {
            self.apiKeyTextField.stringValue = apiKey
        }
        
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        let maxConnections = (maxConcurrentRequests.stringValue as NSString).integerValue
        if maxConnections > 0 {
            PreferencesManager.updateMaxConnections(maxConnections)
        }
        
        PreferencesManager.updateAPIKey(apiKeyTextField.stringValue)
        
    }
    
}
