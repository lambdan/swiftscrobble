//
//  ContentView.swift
//  swiftscrobble
//
//  Created by David Silverlind on 2021-04-21.
//

import SwiftUI

struct ContentView: View {
    @State var song_artist = "Artist"
    @State var song_title = "Title"
    @State var song_album = "Album"
    @State var player = "Player"
    @State var scrobble_status = "?"
    @State var MusicState = "stopped"
    @State var ScrobbleProgress: Float = 0.0
    @State var SongProgress: Float = 0.0
    @State var authenticated = isLastFMInfoEntered()
    @State var scrobbling_enabled = isScrobblingEnabled()
    @State var listen_time = "00:00"
    @State var duration = "??:??"
    @State var PlayingStatusSymbol = "pause.fill"
    @State var listen_time_string = "00:00 / ??:??"
    
    let pub = NotificationCenter.default.publisher(for: NSNotification.Name(NCName))
    
    var body: some View {
        Group {
            

                
            if authenticated == true && MusicState != "stopped" {
                
                VStack {
                    HStack {
                        Image(systemName: PlayingStatusSymbol).font(.system(size: 30)).padding()
                        Text(player).padding()
                    }
                    
                        Text(song_title).fontWeight(.bold)
                        Text(song_artist)
                        Text(song_album)
                        //Text(listen_time + " / " + duration)
                    
                    ProgressBar(value: $ScrobbleProgress, label: $scrobble_status, bgcolor: NSColor.systemGray, fillcolor: NSColor.systemRed).frame(height: 40).padding()
                    //ProgressBar(value: $SongProgress, label: $listen_time_string, bgcolor: NSColor.systemGray, fillcolor: NSColor.systemBlue).frame(height: 20)
                    
                    
                    //Text("Scrobbling enabled: " + String(scrobbling_enabled))
                    //Text("Scrobbled: " + scrobble_status)
                }.onReceive(pub) {_ in
                    //print(Date(), "UI got update request")
                    
                    // This gets run when notification is sent
                    self.song_artist = get_artist()
                    self.song_title = get_title()
                    self.song_album = get_album()
                    self.player = get_player()
                    self.ScrobbleProgress = GetScrobbleProgress()
                    self.SongProgress = GetSongProgress()
                    self.scrobble_status = get_scrobble_status()
                    self.MusicState = getState()
                    self.scrobbling_enabled = isScrobblingEnabled()
                    self.authenticated = isLastFMInfoEntered()
                    self.listen_time = secsToMMSS(secs:getListenedTime())
                    self.duration = secsToMMSS(secs:getDuration())
                    self.listen_time_string = listen_time + " / " + duration
                    
                    
                    if MusicState == "playing" {
                        self.PlayingStatusSymbol = "play.fill"
                    } else {
                        self.PlayingStatusSymbol = "pause.fill"
                    }
                    
                    
                }
            } else if authenticated == true && MusicState == "stopped" {
                // No music playing
                VStack {
                    Image(systemName: "stop.fill").font(.system(size: 30)).padding()
                    Text("No music is playing")
                }
            } else {
                VStack {
                    Text("Last.fm info not entered. Open Settings and enter them.")
                }
            }
            
            HStack { // Buttons
                if authenticated == true {
                    Button(action: {
                        OpenLastFMProfile()
                    }) {
                        Image(systemName: "person")
                    }.padding()
                }
                Button(action: {
                    OpenStatsWindow()
                }) {
                    Image(systemName: "info.circle")
                }.padding()
                Button(action: {
                    OpenSettingsWindow()
                }) {
                    Image(systemName: "gear")
                }.padding()
                Button(action: {
                    QuitMyself()
                }) {
                    Image(systemName: "clear")
                }.padding()
            }
            
        }.onReceive(pub) {_ in
            self.authenticated = isLastFMInfoEntered()
            self.MusicState = getState()
        }
            
            
        
        .padding()
        .frame(minWidth: 300, maxWidth: 300, minHeight: 280, maxHeight: 280)
    }
}

struct SettingsView: View {
    @State private var apikey = preferences.string(forKey: "apikey")!
    @State private var apisecret = preferences.string(forKey: "apisecret")!
    @State private var username = preferences.string(forKey: "username")!
    @State private var password = preferences.string(forKey: "password")!
    @State private var scrobbling_enabled = preferences.bool(forKey: "scrobbling enabled")
    @State private var blacklisted_string = preferences.string(forKey: "blacklisted apps")!
    @State private var changed = false
    
    var body: some View {
        VStack {
            
            VStack { // Last.fm settings block
                
                HStack {
                    Toggle("Enable Scrobbling", isOn: $scrobbling_enabled).onChange(of: scrobbling_enabled) { newvalue in
                        if newvalue == preferences.bool(forKey: "scrobbling enabled") {
                            changed = false
                        } else {
                            changed = true
                        }
                    }
                }
                HStack {
                    Text("Get API keys here:")
                    Link("https://www.last.fm/api/account/create", destination: URL(string: "https://www.last.fm/api/account/create")!)
                }
                HStack {
                    Text("API Key:")
                    TextField("", text: $apikey).onChange(of: apikey) { newvalue in
                        if newvalue == preferences.string(forKey: "apikey") { // Only activate Save button if there is a change
                            changed = false
                        } else {
                            changed = true
                        }
                    }
                }
                HStack {
                    Text("API Secret:")
                    TextField("", text: $apisecret).onChange(of: apisecret) { newvalue in
                        if newvalue == preferences.string(forKey: "apisecret") {
                            changed = false
                        } else {
                            changed = true
                        }
                    }
                }
                HStack {
                    Text("Username:")
                    TextField("", text: $username).onChange(of: username) { newvalue in
                        if newvalue == preferences.string(forKey: "username") {
                            changed = false
                        } else {
                            changed = true
                        }
                    }
                }
                HStack {
                    Text("Password:")
                    SecureField("", text: $password).onChange(of: password) { newvalue in
                        if newvalue == preferences.string(forKey: "password") {
                            changed = false
                        } else {
                            changed = true
                        }
                    }
                }
            }.padding()
            
            HStack {
                Text("Ignored apps:")
                TextField("", text: $blacklisted_string).onChange(of: blacklisted_string) { newvalue in
                    if newvalue == preferences.string(forKey: "blacklisted apps") {
                        changed = false
                    } else {
                        changed = true
                    }
                }
            }.padding()
            
            Button("Save") {
                updatedSettings(username:self.username, password:self.password, apikey:self.apikey, apisecret:self.apisecret, scrobblingenabled: self.scrobbling_enabled, blacklisted: self.blacklisted_string)
            }.padding().disabled(changed == false)
        }.frame(minWidth: 800, maxHeight: 800).padding()
    }
}

struct StatsView: View {
    @State private var songs_scrobbled = preferences.integer(forKey: "songs scrobbled")
    @State private var program_version = get_program_version()
    @State private var reset_clicked = reset_button_times_clicked
    
    var body: some View {
        VStack {
            Text("swiftscrobble version " + program_version)
            Text("Scrobbles: " + String(songs_scrobbled)).padding()
            VStack {
                Button("⚠️ Reset Everything and Quit ⚠️") {
                    self.reset_clicked = reset_button_times_clicked
                    resetDefaults()
                }
                if reset_clicked > 0 {
                    Text("click it " + String(9-reset_clicked) + " more time(s)")
                }
                
            }.padding()
        }.padding().frame(minWidth: 400, maxHeight: 400).padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ProgressBar: View { // shamelessly stolen from https://www.simpleswiftguide.com/how-to-build-linear-progress-bar-in-swiftui/
    @Binding var value: Float
    @Binding var label: String
    @State var bgcolor: NSColor
    @State var fillcolor: NSColor
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                
                Rectangle().frame(width: geometry.size.width , height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color(bgcolor))
                
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color(fillcolor))
                    .animation(.linear)
                
                Text(self.label).frame(maxWidth: .infinity, alignment: .center)
            }.cornerRadius(45.0)
            
        }
    }
}
