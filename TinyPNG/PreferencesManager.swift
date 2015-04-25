import Foundation

class PreferencesManager {
    
    class func initialize() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let maxConnections = userDefaults.valueForKey(Config.Preferences.MaxConnections) as? Int
        if maxConnections == nil {
            self.updateMaxConnections(3)
        }
    }
    
    class func updateMaxConnections(max:Int) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setInteger(max, forKey: Config.Preferences.MaxConnections)
        userDefaults.synchronize()
    }
    
    class func getMaxConnections() -> Int {
        return NSUserDefaults.standardUserDefaults().valueForKey(Config.Preferences.MaxConnections) as! Int
    }
    
    class func updateAPIKey(key:String) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setValue(key, forKey: Config.Preferences.APIKey)
        userDefaults.synchronize()
    }
    
    class func getAPIKey() -> String? {
        return NSUserDefaults.standardUserDefaults().valueForKey(Config.Preferences.APIKey) as? String
    }
    
}
