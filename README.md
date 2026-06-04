![scrobbling in cliamp](https://github.com/tetsuo76/cliamp-lastfm/blob/main/screenshot.png?raw=true)

### Simple last.fm plugin v1.6.0 for [cliamp](https://github.com/bjarneo/cliamp)

Info about last.fm authentication (in order to create your **API_KEY** and **API_SECRET**):
https://www.last.fm/api/authentication

Useful python app to obtain your **SESSION_KEY**:
https://github.com/TheMemoman/lastfm_Get_Session_Key

### Installation/Config:

#### Method 1:

- Copy the plugin (lastfm.lua) into the cliamp's plugins directory (`~/.config/cliamp/plugins`). 

#### Method 2:

- Install it via cliamp with 
```
cliamp plugins install tetsuo76/cliamp-lastfm
```

- Edit cliamp's config file (`~/.config/cliamp/config.toml`) and add the required last.fm section:

```
[plugins.lastfm]
api_key = "API_KEY"
api_secret = "API_SECRET"
session_key = "SESSION_KEY"
username = "LASTFM_USERNAME"
```

- Replace **API_KEY**, **API_SECRET**, **SESSION_KEY** and **LASTFM_USERNAME** username with your own.

### Update: 

- Remove the plugin first
```
cliamp plugins remove cliamp-lastfm
```
- and install the latest version using the cliamp command
```
cliamp plugins install tetsuo76/cliamp-lastfm
```

### Track Loving System:

- Love/Unlove Toggle (`*` key): Press asterisk to love the current track or unlove it if already loved
- Loved Track Detection: Automatically displays "♥ Loved Track" notification when a loved track starts playing
- Scrobble success messages include real-time stats: total tracks, total artists, and session count

### Operating Modes:
| Feature | Normal Mode | Silence Mode | Deactivated Mode |
|---|---|---|---|
| Scrobbling | Enabled | Enabled | Disabled |
| Last.fm API Calls | Enabled | Enabled | Disabled |
| UI Notifications | Enabled | Disabled | Disabled |
| Love / Unlove | Enabled | Enabled | Disabled |
| Purpose | Default behavior | Distraction-free usage | Fully disable Last.fm integration |

**Mode Toggle Keybind:** `&`

Tested with cliamp v1.56.0. Scrobbling works with local files, radios, Spotify and Plex. It should work with other providers but I wasn't able to test them. 
