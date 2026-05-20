![scrobbling in cliamp](https://github.com/tetsuo76/cliamp-lastfm/blob/main/screenshot.png?raw=true)

## Important Note:
Some important changes since version 1.4.1:
- The filename of the .lua file was renamed to `~/.config/cliamp/plugins/cliamp-lastfm.lua`
- and you need to change `[plugins.lastfm]` to `[plugins.cliamp-lastfm]` in your `~/.config/cliamp/config.toml` file.

The above changes were necessary in order for the `cliamp plugins install` command to work properly.


### Simple last.fm plugin v1.5.0 for [cliamp](https://github.com/bjarneo/cliamp)

### Last.fm Authentication

Info about last.fm authentication (in order to create your **API_KEY** and **API_SECRET**):
https://www.last.fm/api/authentication

Useful python app to obtain your **SESSION_KEY**:
https://github.com/TheMemoman/lastfm_Get_Session_Key

### Installation/Config:

#### Method 1:

- Copy the plugin (cliamp-lastfm.lua) into the cliamp's plugins directory (`~/.config/cliamp/plugins`). 

#### Method 2:

- Install it via cliamp with 
```
cliamp plugins install tetsuo76/cliamp-lastfm
```

- Edit cliamp's config file (`~/.config/cliamp/config.toml`) and add the required last.fm section:

```
[plugins.cliamp-lastfm]
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

Tested with cliamp v1.51.1
