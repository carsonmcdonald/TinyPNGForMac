import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidBecomeActive(notification: NSNotification) {
        
        PreferencesManager.initialize()
        
    }

}

