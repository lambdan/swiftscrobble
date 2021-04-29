//
//  swiftscrobbleApp.swift
//  swiftscrobble
//
//  Created by David Silverlind on 2021-04-21.
//

import SwiftUI
import Cocoa


let NCName = "swiftscrobble"
let scrob_path = String( Bundle.main.path(forResource: "scrob", ofType: "py")! ) // https://stackoverflow.com/a/61134616
let preferences = UserDefaults.standard

var registered = false // if remote monitor is registered
var timer = Timer()
let UpdateTimerFrequency = 1.0

var g_player = "?"
var g_artist = ""
var g_title = ""
var g_album = ""
var g_duration = 0.0
var g_state = "stopped" // paused or playing

var paused_at = 0.0
var last_state = ""
var last_song_id = ""

var time_listened = 0.0
var last_timer_tick = 0.0
var ScrobbleConditionsMet = false
var scrobble_msg = ""

var s_apikey = ""
var s_apisecret = ""
var s_username = ""
var s_password = ""
var s_scrobbling_enabled = false
var s_blacklisted_apps = ""
var s_scrobbled_songs = 0

var reset_button_times_clicked = 0

var statusBarItem: NSStatusItem!
var currentMenuBarIcon = ""

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



func NowPlayingInfoTrigger(notification: Notification) {
    let MusicPlayer = (notification.userInfo?["kMRMediaRemoteNowPlayingApplicationDisplayNameUserInfoKey"] ?? "") as! String
    
    if s_blacklisted_apps.contains(MusicPlayer) {
        print("NowPlayingInfoTrigger - ignoring blacklisted app:", MusicPlayer)
        return
    }
    
    if MusicPlayer == "" {
        print("NowPlayingInfoTrigger - music stopped?")
        MusicStopped()
        return
    }

    MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main, { (information) in
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
        
        if local_artist != "" && local_title != "" && local_duration > 0 && MusicPlayer != "" {
            ChangeDetected(artist:local_artist, title:local_title, album: local_album, duration:local_duration, paused:local_paused_at, pbrate:local_playbackrate, player:MusicPlayer)
        }
    })
}



func startMonitoring() {
    if registered == false {
        _ = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                object: nil, queue: nil,
                using: NowPlayingInfoTrigger)
        
        MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main) // This line is important, dont delete it
        print("Registered")
        registered = true
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
    }
}

func newSong() {
    print(Date(), "New song!")
    timer.invalidate()
    last_timer_tick = Date().timeIntervalSince1970
    time_listened = 0
    paused_at = 0
    ScrobbleConditionsMet = false
    scrobble_msg = ""
    send_NC(text: "new song!")
    timer = Timer.scheduledTimer(withTimeInterval: UpdateTimerFrequency, repeats: true) { timer in
        update_time_listened()
    }
    updateMenuBarIcon()
}

func ChangeDetected(artist: String, title: String, album: String, duration:Double, paused:Double, pbrate:Double, player: String) {
    //print("CD", artist, title, album, duration, paused, pbrate, player)
    print("--- ChangeDetected ---")
    print("Player:", player)
    print("Artist:", artist)
    print("Title:", title)
    print("Album:", album)
    print("Duration:", duration)
    print("Paused at:", paused)
    print("Playback rate:", pbrate)
    
    
    /*if g_state == "playing" && player != g_player && g_player != "?" {
        print("Preventing new player from taking over!!!")
        print("Current player:", g_player)
        print("Want to take over:", player)
        return
    } else if g_state == "paused" || g_state == "stopped" {
        print("Allowing new player")
        g_player = player
    }*/
    g_player = player
    
    if pbrate == 0 {
        g_state = "paused"
    } else {
        g_state = "playing"
    }
    
    let song_id = title+artist+album+String(duration)
    if song_id != last_song_id {
        print("--> New song !!!")
        newSong() // resets vals
        last_song_id = song_id

        g_artist = artist
        g_duration = duration
        g_title = title
        g_album = album
    } else {
        print("--> same song")
    }

    if g_state == "paused" {
        print("Pause condition reached")
        paused_at = paused
    }
    
    if g_state == "playing" && paused_at > 0 {
        print("Playing & paused at > 0 condition reached.")
        if paused_at <= 0.1 {
            print("(Ugly repeat hack executing)")
            newSong()
        }
    }
    
    send_NC(text: "update ui plz")
    updateMenuBarIcon()
    print("-------end of ChangeDetected-------")
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
        last_timer_tick = Date().timeIntervalSince1970 // Otherwise we will get the time you were paused added
        return
    }
    
    time_listened = time_listened + (Date().timeIntervalSince1970 - last_timer_tick)
    
    // repeat?
    if time_listened >= g_duration {
        print("time listened > duration = repeat ?")
        newSong()
    }
    
    // scrobble condtions met?
    if ScrobbleConditionsMet == false {
        if g_duration >= 30 && time_listened >= (g_duration/2) || g_duration > 480 && time_listened > 240 {
            ScrobbleConditionsMet = true
            updateMenuBarIcon()
            scrobble(artist: g_artist, title: g_title, album: g_album, unixtime: Date().timeIntervalSince1970)
        }
    }
    
    send_NC(text: "timer update")
    last_timer_tick = Date().timeIntervalSince1970
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
        
        // Update scrobble counter
        let new_total_scrobbles = preferences.integer(forKey: "songs scrobbled") + 1
        preferences.set(new_total_scrobbles, forKey: "songs scrobbled")
        
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

func updatedSettings(username: String, password: String, apikey: String, apisecret: String, scrobblingenabled: Bool, blacklisted: String) {
    print("Saving settings")
    preferences.set(username, forKey: "username")
    preferences.set(password, forKey: "password")
    preferences.set(apikey, forKey: "apikey")
    preferences.set(apisecret, forKey: "apisecret")
    preferences.set(blacklisted, forKey: "blacklisted apps")
    preferences.set(scrobblingenabled, forKey: "scrobbling enabled")
    loadUserDefaults()
}

func loadUserDefaults() {
    print("Loading userdefaults")
    
    if isKeyPresentInUserDefaults(key: "username") == false {
        print("Reset: username")
        preferences.set("", forKey: "username")
    }
    s_username = preferences.string(forKey: "username")!
    
    if isKeyPresentInUserDefaults(key: "password") == false {
        print("Reset: password")
        preferences.set("", forKey: "password")
    }
    s_password = preferences.string(forKey: "password")!
    
    if isKeyPresentInUserDefaults(key: "apikey") == false {
        print("Reset: apikey")
        preferences.set("", forKey: "apikey")
    }
    s_apikey = preferences.string(forKey: "apikey")!
    
    if isKeyPresentInUserDefaults(key: "apisecret") == false {
        print("Reset: apisecret")
        preferences.set("", forKey: "apisecret")
    }
    s_apisecret = preferences.string(forKey: "apisecret")!
    
    if isKeyPresentInUserDefaults(key: "scrobbling enabled") == false {
        print("Reset: scrobbling enabled")
        preferences.set(false, forKey: "scrobbling enabled")
    }
    s_scrobbling_enabled = preferences.bool(forKey: "scrobbling enabled")
    
    if isKeyPresentInUserDefaults(key: "blacklisted apps") == false {
        print("Reset: blacklisted apps")
        preferences.set("Safari, Google Chrome, Spotify, Plex, Plexamp", forKey: "blacklisted apps")
    }
    // TODO this should be converted to a list instead of just being a string
    s_blacklisted_apps = preferences.string(forKey: "blacklisted apps")!
    
    if isKeyPresentInUserDefaults(key: "songs scrobbled") == false {
        print("Reset: songs scrobbled")
        preferences.set(0, forKey: "songs scrobbled")
    }
    s_scrobbled_songs = preferences.integer(forKey: "songs scrobbled")
    
    
    if isLastFMInfoEntered() == true && registered == false {
        print("Starting monitoring...")
        getNowPlayingNow()
        startMonitoring()
    }
    

    updateMenuBarIcon()
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
                ChangeDetected(artist: local_artist, title: local_title, album: local_album, duration: local_duration, paused: 0.0, pbrate: local_playbackrate, player: "?")
            }
            
            
            
        }
        

    })
}

func MusicStopped() {
    print(Date(), "Music Stopped")
    g_state = "stopped"
    last_song_id = ""
    timer.invalidate()
    updateMenuBarIcon()
    send_NC(text: "music stopped?")
}

func CacheScrobble(artist: String, title: String, album: String, date: Double) {
    // CacheScrobble for when scrobbling fails to retry at a later time
    print("Cache Scrobble:", artist, title, album, date)
    // TODO implement (add song to an array, save array to UserDefaults, have menubar option to show cached scrobbles, have button to retry scrobbling them
    
}



class AppDelegate: NSObject, NSApplicationDelegate {
    var popover = NSPopover.init()
    

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationdidfinishlaunching")
        loadUserDefaults()
        
        let contentView = ContentView()

        // Set the SwiftUI's ContentView to the Popover's ContentViewController
        popover.behavior = .transient // !!! - This does not seem to work in SwiftUI2.0 or macOS BigSur yet
        popover.animates = true
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.image = NSImage(systemSymbolName: "stop", accessibilityDescription: nil)
        statusBarItem?.button?.action = #selector(AppDelegate.togglePopover(_:))
        self.popover.contentViewController?.view.window?.becomeKey()
        updateMenuBarIcon()
        
        
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
    NSApp.activate(ignoringOtherApps: true)
    windowRef.isReleasedWhenClosed = false
}

func OpenStatsWindow() {
    var windowRef: NSWindow
    windowRef = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
    windowRef.title = "Stats"
    windowRef.center()
    windowRef.contentView = NSHostingView(rootView: StatsView())
    windowRef.makeKeyAndOrderFront(windowRef)
    NSApp.activate(ignoringOtherApps: true)
    windowRef.isReleasedWhenClosed = false
}

func QuitMyself() {
    NSApp.terminate(nil)
}


func OpenLastFMProfile() {
    if let url = URL(string: "https://www.last.fm/user/" + s_username) {
        NSWorkspace.shared.open(url)
    }
}

func get_player() -> String {
    return g_player
}

func get_blacklisted() -> String {
    return s_blacklisted_apps
}

func get_program_version() -> String {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    return appVersion!
}

func resetDefaults() {
    reset_button_times_clicked += 1
    print("reset button clicked:", reset_button_times_clicked)
    if reset_button_times_clicked >= 10 {
        print("RESET ALL AND QUIT")
        let dictionary = preferences.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            preferences.removeObject(forKey: key)
        }
        NSApp.terminate(nil)
        
    }
}

func updateMenuBarIcon() {
    if isLastFMInfoEntered() == false {
        setIcon(icon: "person.crop.circle.badge.questionmark")
    } else if isScrobblingEnabled() == false && g_state == "playing" {
        setIcon(icon: "play.circle")
    } else if isScrobblingEnabled() == true && ScrobbleConditionsMet {
        if g_state == "paused" {
            setIcon(icon: "pause.circle.fill")
        } else if g_state == "playing" {
            setIcon(icon: "play.circle.fill")
        }
    } else if g_state == "paused" {
        setIcon(icon: "pause.circle")
    } else if g_state == "playing" {
        setIcon(icon: "play.circle")
    } else {
        setIcon(icon: "stop.circle")
    }
}

func setIcon(icon: String) {
    if icon != currentMenuBarIcon {
        statusBarItem?.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        currentMenuBarIcon = icon
    } else {
        return
    }
}
