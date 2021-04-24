import pylast # pip3 install pylast
import time, sys, base64

# base64 all the things to prevent $ escaping bash quotes
artist = base64.b64decode(sys.argv[1]).decode("utf8")
title = base64.b64decode(sys.argv[2]).decode("utf8")
API_KEY = base64.b64decode(sys.argv[3]).decode("utf8")
API_SECRET = base64.b64decode(sys.argv[4]).decode("utf8")
USERNAME = base64.b64decode(sys.argv[5]).decode("utf8")
PASSWORD = base64.b64decode(sys.argv[6]).decode("utf8")
datestamp = float(base64.b64decode(sys.argv[7]).decode("utf8"))
album = base64.b64decode(sys.argv[8]).decode("utf8")


#print("in", sys.argv)
#print("decoded", artist, title, API_KEY, API_SECRET, USERNAME, PASSWORD,datestamp)

network = pylast.LastFMNetwork(
    api_key=API_KEY,
    api_secret=API_SECRET,
    username=USERNAME,
    password_hash=pylast.md5(PASSWORD),
)



# api keys can be created: https://www.last.fm/api/account/create

#timestamp = int(time.time())
# convert datestamp to unixtime
#timestamp = (int(datetime.datetime.strptime(datestamp, '%Y-%m-%d %H:%M:%S %z').strftime("%s")))
timestamp = int(datestamp)
#print("timestamp:",timestamp)

#print("Artist:", artist)
#print("Title:", title)
#confirm = input("OK?")
if album == "": # no album
    network.scrobble(artist=artist, title=title, timestamp=timestamp)
    print("OK (no album)")
else: # album set
    network.scrobble(artist=artist, title=title, timestamp=timestamp, album=album)
    print("OK (with album)", end="")
