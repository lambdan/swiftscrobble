//
//  swiftscrobbleApp.swift
//  swiftscrobble
//
//  Created by David Silverlind on 2021-04-21.
//

import SwiftUI
import Cocoa


let NCName = "swiftscrobble"
let version = 0.1
let scrob_path = String( Bundle.main.path(forResource: "scrob", ofType: "py")! ) // https://stackoverflow.com/a/61134616
let preferences = UserDefaults.standard

var registered = false // if remote monitor is registered
var i = 0
var timer = Timer()
let timer_inc = 0.1

var g_artist = ""
var g_title = ""
var g_album = ""
var g_duration = 0.0
var g_state = "stopped" // paused or playing

var playbackrate = 0.0

var paused_at = 0.0
var last_state = ""
var last_song_id = ""

var time_listened = 0.0
var ScrobbleConditionsMet = false
var scrobble_msg = ""

var s_apikey = ""
var s_apisecret = ""
var s_username = ""
var s_password = ""
var s_scrobbling_enabled = false

// disable menu bar items


// setup now playing monitoring
let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(
    bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString
)
typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
let MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(
    bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
var MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(
    MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self
)

func shell(_ command: String) -> String { // https://stackoverflow.com/a/50035059
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    NSLog(output)
    return output
}


@main
struct swiftscrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        /*WindowGroup {
            ContentView()
        }*/
        Settings { // lol, hack to not show window on launch: https://www.reddit.com/r/SwiftUI/comments/hltt9a/is_it_possible_to_create_a_menubar_app_with/fx1hsi4/
            EmptyView()
        }
        /*
        WindowGroup("Preferences") {
            SettingsView().handlesExternalEvents(preferring: Set(arrayLiteral: "prefs"), allowing: Set(arrayLiteral: "*")) // activate existing window if exists
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "prefs")) // create new window if one doesn't exist
 */
    }
}





func startMonitoring() {
    if registered == false {
    MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
    
    NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: nil) { (notification) in
            //print(notification)
            MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { (information) in
            //print(i, information)
            if i > 2 {
                // because we get 3 notifications for some reason? TODO
                i = 0
                //return
            }
                
            var local_artist = ""
            var local_title = ""
            var local_album = ""
            var local_duration = 0.0
            var local_playbackrate = 0.0
            var local_paused_at = 0.0
            
            if (information["kMRMediaRemoteNowPlayingInfoArtist"] != nil) {
                local_artist = information["kMRMediaRemoteNowPlayingInfoArtist"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoTitle"] != nil) {
                local_title = information["kMRMediaRemoteNowPlayingInfoTitle"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoAlbum"] != nil) {
                local_album = information["kMRMediaRemoteNowPlayingInfoAlbum"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoDuration"] != nil) {
                local_duration = Double(information["kMRMediaRemoteNowPlayingInfoDuration"] as! NSNumber)
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoPlaybackRate"] != nil) {
                local_playbackrate = Double(information["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as! NSNumber)
            }
                
            // kMRMediaRemoteNowPlayingApplicationDisplayNameUserInfoKey == player name
            //print(i, information)
            //print ("player:",information["kMRMediaRemoteNowPlayingApplicationDisplayNameUserInfoKey"])
                
            if (information["kMRMediaRemoteNowPlayingInfoElapsedTime"] != nil) {
                local_paused_at = Double(information["kMRMediaRemoteNowPlayingInfoElapsedTime"] as! NSNumber) // only updates when paused
            }
            
            //if i == 0 {
                // send out data
                if local_artist != "" && local_title != "" && local_duration > 0 {
                    // Should trigger when music player changes
                    ChangeDetected(artist:local_artist, title:local_title, album: local_album, duration:local_duration, paused:local_paused_at, pbrate:local_playbackrate)
                } else if local_artist == "" && local_title != "" && local_duration > 0 {
                    // Should trigger when playing something in a web browser (like youtube)
                    print(Date(), "Youtube trigger?")
                    print(local_artist, local_title, local_duration, local_playbackrate)
                } else {
                    // Seems to trigger when music player is quit
                    print(Date(), "ELSE TRIGGER")
                    MusicStopped()
                }
            //}
            
            // because we get 3 notifications for some reason
            i = i + 1
            
        })
    }
        
    
    print("Registered")
    registered = true
    }
}

func newSong() {
    print(Date(), "New song!")
    timer.invalidate()
    time_listened = 0
    paused_at = 0
    ScrobbleConditionsMet = false
    scrobble_msg = ""
    send_NC(text: "new song!")
    timer = Timer.scheduledTimer(withTimeInterval: timer_inc, repeats: true) { timer in
        update_time_listened()
    }
}

func ChangeDetected(artist: String, title: String, album: String, duration:Double, paused:Double, pbrate:Double) {
    print("CD", artist, title, album, duration, paused, pbrate)
    if pbrate == 0 {
        g_state = "paused"
    } else {
        g_state = "playing"
    }
    
    let song_id = title+artist+album+String(duration)
    if song_id != last_song_id {
        print("CD new song trigger", artist, title, album, duration)
        newSong() // resets vals
        last_song_id = song_id
        
        g_artist = artist
        g_duration = duration
        g_title = title
        g_album = album
    }

    if g_state == "paused" {
        print("CD pause trigger", paused, title, artist, duration)
        paused_at = paused
    }
    
    if g_state == "playing" && paused_at > 0 {
        print("CD playing & paused at > 0 trigger")
        if paused_at <= 0.1 {
            print("CD ugly repeat hack")
            newSong()
        }
    }
    
    send_NC(text: "update ui plz")
}



func send_NC(text: String) {
    //print("NC:", text)
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: NCName), object: nil)
}

func GetScrobbleProgress() -> Float {
    if isScrobblingEnabled() == false {
        return 0
    } else if g_duration < 30 {
        return 0
    } else if g_duration > 480 { // 4 minute trigger
        return Float(time_listened/240) // 240 = 4 minutes
    } else {
        return Float(time_listened / (g_duration/2))
    }
   
}

func GetSongProgress() -> Float {
    return Float(time_listened/g_duration)
}

func update_time_listened() {
    
    if g_state == "paused" {
        return
    }
    
    time_listened = time_listened + timer_inc
    
    // repeat?
    if time_listened >= g_duration {
        print("time listened > duration = repeat ?")
        newSong()
    }
    
    // scrobble condtions met?
    if g_duration >= 30 && time_listened >= (g_duration/2) && ScrobbleConditionsMet == false || g_duration > 480 && time_listened > 240 && ScrobbleConditionsMet == false {
        ScrobbleConditionsMet = true
        scrobble(artist: g_artist, title: g_title, album: g_album, unixtime: Date().timeIntervalSince1970)
    }
    
    //print("update time listened: ", time_listened)
    send_NC(text: "timer update")
}

func scrobble(artist: String, title: String, album: String, unixtime: Double) {
    print("SCROBBLE:", artist, "-", title, unixtime, album)
    
    if isScrobblingEnabled() == false {
        print("SCROBBLING DISABLED")
        return
    }
        
    // make sure user has entered info
    if isLastFMInfoEntered() == false {
        print("scrobble fail because no user info")
        return
    }
    
    // scrobble using python, this is extremely hacky
    // artist, title, apikey, apisecret, username, password(base64encoded)
    scrobble_msg = "Scrobbling..."
    send_NC(text: "scrobbling...")
    
    let cmd = shell("python3 " + scrob_path + " \"" + Data(artist.utf8).base64EncodedString() + "\" \"" + Data(title.utf8).base64EncodedString() + "\" \"" + Data(s_apikey.utf8).base64EncodedString() + "\" \"" + Data(s_apisecret.utf8).base64EncodedString() + "\" \"" + Data(s_username.utf8).base64EncodedString() + "\" \"" + Data(s_password.utf8).base64EncodedString() + "\" \"" + Data(String(unixtime).utf8).base64EncodedString() + "\" \"" + Data(String(album).utf8).base64EncodedString() + "\"")
    if cmd.contains("OK") {
        scrobble_msg = "Scrobbled"
        print(Date(), "Scrobble Success")
    } else {
        scrobble_msg = "Scrobble failed"
        print(Date(), "Scrobble failed :(")
        CacheScrobble(artist: artist, title: title, album: album, date: unixtime)
    }
    send_NC(text: "scrobbled")
}

func get_scrobble_status() -> String {
    if isScrobblingEnabled() == false {
        return "Scrobbling disabled"
    } else if g_duration < 30 {
        return "Song is too short"
    } else if ScrobbleConditionsMet == true {
        return scrobble_msg
    } else if g_duration > 480 { // 4 mins condition
        return "Scrobbles in " + secsToMMSS(secs: 240 - time_listened)
    } else {
        return "Scrobbles in " + secsToMMSS(secs: (g_duration/2) - time_listened)
    }
}

func get_pbar_color() -> NSColor {
    if isScrobblingEnabled() == false {
        return NSColor.systemGray
    } else if ScrobbleConditionsMet == true {
        return NSColor.systemGreen
    } else if g_state == "paused" {
        return NSColor.systemGray
    } else {
        return NSColor.systemBlue
    }
    
    
}

func updatedSettings(username: String, password: String, apikey: String, apisecret: String, scrobblingenabled: Bool) {
    print("Saving settings")
    preferences.set(username, forKey: "username")
    preferences.set(password, forKey: "password")
    preferences.set(apikey, forKey: "apikey")
    preferences.set(apisecret, forKey: "apisecret")
    preferences.set(scrobblingenabled, forKey: "scrobbling enabled")
    loadUserDefaults()
}

func initializeUserDefaults() {
    print("Init userdefaults")
    preferences.set("", forKey: "apikey")
    preferences.set("", forKey: "apisecret")
    preferences.set("", forKey: "username")
    preferences.set("", forKey: "password")
    preferences.set(false, forKey: "scrobbling enabled")
    print("Init ok")
    loadUserDefaults()
    
    
}

func loadUserDefaults() {
    print("Loading stored userdefaults")
    s_username = preferences.string(forKey: "username")!
    s_password = preferences.string(forKey: "password")!
    s_apikey = preferences.string(forKey: "apikey")!
    s_apisecret = preferences.string(forKey: "apisecret")!
    s_scrobbling_enabled = preferences.bool(forKey: "scrobbling enabled")
    
    
    if isLastFMInfoEntered() == true && registered == false {
        print("Starting monitoring...")
        getNowPlayingNow()
        startMonitoring()
    }
    
    send_NC(text: "loaded data")
}

func isKeyPresentInUserDefaults(key: String) -> Bool { // https://smartcodezone.com/check-if-key-is-exists-in-userdefaults-in-swift/
       return UserDefaults.standard.object(forKey: key) != nil
}

func isLastFMInfoEntered() -> Bool {
    
    if s_username != "" && s_password != "" && s_apikey != "" && s_apisecret != "" {
        return true
    } else {
        return false
    }
}

func isMusicPlaying() -> Bool {
    if g_state == "playing" {
        return true
    } else {
        return false
    }
}

func getState() -> String {
    return g_state
}

func isScrobblingEnabled() -> Bool {
    return s_scrobbling_enabled
}

func getListenedTime() -> Double {
    return time_listened
}

func getDuration() -> Double {
    return g_duration
}

func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) { // https://stackoverflow.com/a/26794841
  return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
}

func secsToMMSS(secs:Double) -> String {
    let (h,m,s) = secondsToHoursMinutesSeconds(seconds: Int(secs))
    return String(format: "%02d", m) + ":" + String(format: "%02d", s)
}

func get_artist() -> String {
    return g_artist
}

func get_title() -> String {
    return g_title
}

func get_album() -> String {
    return g_album
}

func getNowPlayingNow() {
    let task = MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { (information) in
        
        if (information["kMRMediaRemoteNowPlayingInfoDuration"] == nil) { // if duration is not set = nothing is playing
        } else {
            var local_artist = ""
            var local_title = ""
            var local_album = ""
            var local_duration = 0.0
            var local_playbackrate = 0.0
            var local_paused_at = 0.0
            
            if (information["kMRMediaRemoteNowPlayingInfoArtist"] != nil) {
                local_artist = information["kMRMediaRemoteNowPlayingInfoArtist"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoTitle"] != nil) {
                local_title = information["kMRMediaRemoteNowPlayingInfoTitle"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoAlbum"] != nil) {
                local_album = information["kMRMediaRemoteNowPlayingInfoAlbum"] as! String
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoDuration"] != nil) {
               local_duration = Double(information["kMRMediaRemoteNowPlayingInfoDuration"] as! NSNumber)
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoPlaybackRate"] != nil) {
                local_playbackrate = Double(information["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as! NSNumber)
            }
            
            if (information["kMRMediaRemoteNowPlayingInfoElapsedTime"] != nil) {
                local_paused_at = Double(information["kMRMediaRemoteNowPlayingInfoElapsedTime"] as! NSNumber) // only updates when paused
            }
            
            if local_artist != "" && local_duration > 0 && local_title != "" {
                ChangeDetected(artist: local_artist, title: local_title, album: local_album, duration: local_duration, paused: 0.0, pbrate: local_playbackrate)
            }
            
            
            
        }
        

    })
}

func MusicStopped() {
    print(Date(), "Music Stopped")
    g_state = "stopped"
    last_song_id = ""
    timer.invalidate()
    send_NC(text: "music stopped?")
}

func CacheScrobble(artist: String, title: String, album: String, date: Double) {
    // CacheScrobble for when scrobbling fails to retry at a later time
    print("Cache Scrobble:", artist, title, album, date)
    // TODO implement (add song to an array, save array to UserDefaults, have menubar option to show cached scrobbles, have button to retry scrobbling them
    
}


class AppDelegate: NSObject, NSApplicationDelegate {
    var popover = NSPopover.init()
    var statusBarItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationdidfinishlaunching")
        
        if !(isKeyPresentInUserDefaults(key: "apikey")) { // set up userdefaults if necessary
            initializeUserDefaults()
        } else {
            // load them
            loadUserDefaults()
            
        }
        
        let contentView = ContentView()

        // Set the SwiftUI's ContentView to the Popover's ContentViewController
        popover.behavior = .transient // !!! - This does not seem to work in SwiftUI2.0 or macOS BigSur yet
        popover.animates = true
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        statusBarItem?.button?.action = #selector(AppDelegate.togglePopover(_:))
        self.popover.contentViewController?.view.window?.becomeKey()
        
        
    }
    @objc func showPopover(_ sender: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
//            !!! - displays the popover window with an offset in x in macOS BigSur.
        }
    }
    @objc func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}

func OpenSettingsWindow() {
    var windowRef: NSWindow
    windowRef = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
    windowRef.title = "Settings"
    windowRef.center()
    windowRef.contentView = NSHostingView(rootView: SettingsView())
    windowRef.makeKeyAndOrderFront(windowRef)
    windowRef.isReleasedWhenClosed = false
}
