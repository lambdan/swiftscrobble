# swiftscrobble
Universal Last.fm scrobbler for macOS that lives in your menu bar.

*Should* work with most apps that sends information to the OS (i.e. if it shows up in the macOS Now Playing widget I *should* detect it). I use _foobar2000_ and the built-in _Music.app_ and they seem to work fine.

There are a bunch of [issues](https://github.com/lambdan/swiftscrobble/issues):

Notably, playing a video in a web browser (like YouTube in Safari) while you're listening to music will prevent me from seeing if the song changes which means I will think you are listening to the same song constantly (https://github.com/lambdan/swiftscrobble/issues/14).

Also, the keyboard shortcuts for copy/paste does not work in Settings window when you're inputting your Last.fm API keys. Very annoying. You'll have to right click and pick the options there instead. (https://github.com/lambdan/swiftscrobble/issues/3)

Only tested on my machine so I have no idea if it even works for anyone else. Scrobbling is done using [pylast](https://github.com/pylast/pylast) so you need Python 3 installed (I think it's included by default with recent macOS releases). Might need some pip3 libraries too, who knows.

![Image](https://lambdan.se/img/2021-05-13_23-05-23.186104.png)

Good luck and don't blame me.