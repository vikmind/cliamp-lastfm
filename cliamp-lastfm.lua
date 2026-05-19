local p = plugin.register({
    name = "lastfm",
    type = "hook",
    version = "1.5.0",
    description = "Scrobbles the current track to last.fm",
    permissions = {"keymap"},
})

local api_key = p:config("api_key")
local api_secret = p:config("api_secret")
local session_key = p:config("session_key")
local username = p:config("username")

local API_URL = "http://ws.audioscrobbler.com/2.0/"

local has_scrobbled_current = false
local session_scrobbles = 0
local last_scrobble_time = 0
local message_duration = 10

-- last.fm modes:
-- normal  = everything works, messages shown
-- silent  = everything works, no messages except mode toggle message
-- off     = no messages, no scrobbling, no last.fm API calls
local MODE_NORMAL = "normal"
local MODE_SILENT = "silent"
local MODE_OFF = "off"

local lastfm_mode = MODE_NORMAL

local function lastfm_enabled()
    return lastfm_mode ~= MODE_OFF
end

local function lastfm_silent()
    return lastfm_mode == MODE_SILENT
end

local function lastfm_message(msg, duration)
    if lastfm_enabled() and not lastfm_silent() then
        cliamp.message(msg, duration or message_duration)
    end
end

-- Helper to safely handle properties vs functions
local function get(val)
    if type(val) == "function" then return val() end
    return val
end

local function urlencode(str)
    if not str then return "" end
    str = tostring(str)
    str = string.gsub(str, "([^%w%.%- ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(str, " ", "+")
end

local function format_number(num)
    if type(num) ~= "number" then return tostring(num) end
    local str = tostring(num)
    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
    return formatted
end

local function get_api_sig(params)
    local keys = {}

    for k in pairs(params) do
        if k ~= "format" then
            table.insert(keys, k)
        end
    end

    table.sort(keys)

    local str = ""
    for _, k in ipairs(keys) do
        str = str .. k .. tostring(params[k])
    end

    str = str .. api_secret
    return cliamp.crypto.md5(str)
end

local function build_query_string(params)
    local parts = {}

    for k, v in pairs(params) do
        table.insert(parts, urlencode(k) .. "=" .. urlencode(v))
    end

    return table.concat(parts, "&")
end

local function build_post_body(params)
    return build_query_string(params) .. "&format=json"
end

local function lastfm_get(url)
    if not lastfm_enabled() then
        return nil, "disabled"
    end

    return cliamp.http.get(url)
end

local function lastfm_post(params)
    if not lastfm_enabled() then
        return nil, "disabled"
    end

    return cliamp.http.post(API_URL, {
        body = build_post_body(params),
        headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
    })
end

local function check_track_loved(track)
    if not lastfm_enabled() then return end
    if not username then return end

    local artist = track.artist or track.Artist or ""
    local title = track.title or track.Title or ""

    if artist == "" or title == "" then return end

    local response, status = lastfm_get(API_URL .. "?" .. build_query_string({
        method = "track.getInfo",
        api_key = api_key,
        artist = artist,
        track = title,
        username = username,
        format = "json",
    }))

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and data.track and data.track.userloved == "1" then
            lastfm_message("♥ Loved Track: " .. artist .. " - " .. title, message_duration)
        end
    end
end

local function is_track_loved(artist, title)
    if not lastfm_enabled() then return false end
    if not username then return false end

    local response, status = lastfm_get(API_URL .. "?" .. build_query_string({
        method = "track.getInfo",
        api_key = api_key,
        artist = artist,
        track = title,
        username = username,
        format = "json",
    }))

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and data.track and data.track.userloved == "1" then
            return true
        end
    end

    return false
end

local function get_track_scrobble_count(artist, title)
    if not lastfm_enabled() then return "?" end
    if not username then return "?" end

    local response, status = lastfm_get(API_URL .. "?" .. build_query_string({
        method = "track.getInfo",
        api_key = api_key,
        artist = artist,
        track = title,
        username = username,
        format = "json",
    }))

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and data.track and data.track.userplaycount then
            local count = tonumber(data.track.userplaycount)

            if count then
                return format_number(count)
            end
        end
    end

    return "0"
end

local function get_user_loved_count()
    if not lastfm_enabled() then return "?" end
    if not username then return "?" end

    local response, status = lastfm_get(API_URL .. "?" .. build_query_string({
        method = "user.getLovedTracks",
        api_key = api_key,
        user = username,
        limit = 1,
        format = "json",
    }))

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and data.lovedtracks and data.lovedtracks["@attr"] and data.lovedtracks["@attr"].total then
            local count = tonumber(data.lovedtracks["@attr"].total)

            if count then
                return format_number(count)
            end
        end
    end

    return "?"
end

local function unlove_track()
    if not lastfm_enabled() then return end

    if not username or not session_key then
        lastfm_message("[last.fm] Not configured", message_duration)
        return
    end

    local artist = cliamp.track.artist()
    local title = cliamp.track.title()

    if not artist or not title then
        lastfm_message("[last.fm] No track playing", message_duration)
        return
    end

    local params = {
        method = "track.unlove",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title
    }

    local sig = get_api_sig(params)

    local response, status = lastfm_post({
        method = "track.unlove",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title,
        api_sig = sig,
    })

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and (data.lfm == nil or next(data) == nil) then
            lastfm_message("♡ Unloved: " .. artist .. " - " .. title, message_duration)
        elseif data and data.error then
            cliamp.log.warn("last.fm unlove failed: error code " .. tostring(data.error) .. " - " .. tostring(data.message))
            lastfm_message("[last.fm] Error: " .. tostring(data.message), message_duration)
        else
            cliamp.log.warn("last.fm unlove unexpected response: " .. tostring(response))
            lastfm_message("[last.fm] Unexpected response", message_duration)
        end
    else
        local error_detail = "status=" .. tostring(status)

        if response then
            error_detail = error_detail .. ", response=" .. tostring(response)
        end

        cliamp.log.warn("last.fm unlove failed: " .. error_detail)
        lastfm_message("[last.fm] Unable to unlove track now", message_duration)
    end
end

local function love_track()
    if not lastfm_enabled() then return end

    if not username or not session_key then
        lastfm_message("[last.fm] Not configured", message_duration)
        return
    end

    local artist = cliamp.track.artist()
    local title = cliamp.track.title()

    if not artist or not title then
        lastfm_message("[last.fm] No track playing", message_duration)
        return
    end

    if is_track_loved(artist, title) then
        unlove_track()
        return
    end

    local params = {
        method = "track.love",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title
    }

    local sig = get_api_sig(params)

    local response, status = lastfm_post({
        method = "track.love",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title,
        api_sig = sig,
    })

    if tostring(status) == "200" then
        local data = cliamp.json.decode(response)

        if data and data.lfm and data.lfm.status == "ok" then
            lastfm_message("♥ Loved: " .. artist .. " - " .. title, message_duration)
        elseif data and (data.lfm == nil or next(data) == nil) then
            lastfm_message("♥ Loved: " .. artist .. " - " .. title, message_duration)
        elseif data and data.error then
            cliamp.log.warn("last.fm love failed: error code " .. tostring(data.error) .. " - " .. tostring(data.message))
            lastfm_message("[last.fm] Error: " .. tostring(data.message), message_duration)
        else
            cliamp.log.warn("last.fm love unexpected response: " .. tostring(response))
            lastfm_message("[last.fm] Unexpected response", message_duration)
        end
    else
        local error_detail = "status=" .. tostring(status)

        if response then
            error_detail = error_detail .. ", response=" .. tostring(response)
        end

        cliamp.log.warn("last.fm love failed: " .. error_detail)
        lastfm_message("[last.fm] Unable to love track now", message_duration)
    end
end

local function do_scrobble(track, timestamp)
    if not lastfm_enabled() then return end

    local artist = track.artist or track.Artist or "Unknown"
    local title = track.title or track.Title or "Unknown"
    local album = track.album or track.Album or ""

    local params = {
        method = "track.scrobble",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title,
        album = album,
        timestamp = tostring(timestamp)
    }

    local sig = get_api_sig(params)

    local response, status = lastfm_post({
        method = "track.scrobble",
        api_key = api_key,
        sk = session_key,
        artist = artist,
        track = title,
        album = album,
        timestamp = tostring(timestamp),
        api_sig = sig,
    })

    last_scrobble_time = os.time()

    if tostring(status) == "200" then
        session_scrobbles = session_scrobbles + 1

        local scrobble_count = get_track_scrobble_count(artist, title)
        scrobble_count = (tonumber(scrobble_count) or 0) + 1

        local total_tracks = "?"
        local total_artists = "?"
        local loved_count = "?"

        if username then
            local response2, status2 = lastfm_get(API_URL .. "?" .. build_query_string({
                method = "user.getInfo",
                api_key = api_key,
                user = username,
                format = "json",
            }))

            if tostring(status2) == "200" then
                local data = cliamp.json.decode(response2)

                if data and data.user then
                    total_tracks = tostring(data.user.playcount or "?")
                    total_artists = tostring(data.user.artist_count or "?")

                    if total_tracks ~= "?" then
                        total_tracks = format_number(tonumber(total_tracks))
                    end

                    if total_artists ~= "?" then
                        total_artists = format_number(tonumber(total_artists))
                    end
                end
            end

            loved_count = get_user_loved_count()
        end

        scrobble_count = math.max(1, tonumber(scrobble_count) or 0)

        local times_suffix = scrobble_count == 1 and " time" or " times"

        local primary_message =
            "Scrobble Sent: " ..
            artist ..
            " - " ..
            title ..
            " [Scrobbled: " ..
            format_number(scrobble_count) ..
            times_suffix ..
            "]"

        local stats_message =
            "[Tracks: " ..
            total_tracks ..
            " | Artists: " ..
            total_artists ..
            " | Loved: " ..
            loved_count ..
            " | Session: " ..
            format_number(session_scrobbles) ..
            "]"

        lastfm_message(primary_message, message_duration)

        cliamp.timer.after(message_duration, function()
            lastfm_message(stats_message, message_duration)
        end)
    else
        local error_detail = "status=" .. tostring(status)

        if response then
            error_detail = error_detail .. ", response=" .. tostring(response)
        end

        cliamp.log.warn("last.fm scrobble failed: " .. error_detail)
        lastfm_message("[last.fm] Unable to scrobble now. Check your connection or last.fm status.", message_duration)
    end
end

local function toggle_lastfm_mode()
    if lastfm_mode == MODE_NORMAL then
        lastfm_mode = MODE_SILENT
        cliamp.message("last.fm Silence Mode Activated", message_duration)

    elseif lastfm_mode == MODE_SILENT then
        lastfm_mode = MODE_OFF
        cliamp.message("last.fm Privacy Mode Activated", message_duration)

    else
        lastfm_mode = MODE_NORMAL
        cliamp.message("last.fm Normal Mode Activated", message_duration)
    end
end

-- Catch natural ends via playback position
p:on("track.change", function(track)
    has_scrobbled_current = false

    if not lastfm_enabled() then return end

    local delay = 0

    if os.time() - last_scrobble_time < 3 then
        delay = 2.5
    end

    if delay > 0 then
        cliamp.timer.after(delay, function()
            check_track_loved(track)
        end)
    else
        check_track_loved(track)
    end
end)

p:on("playback.state", function(data)
    if not lastfm_enabled() then return end

    local dur = get(cliamp.player.duration) or 0

    if not has_scrobbled_current and dur >= 30 and data.status == "playing" then
        if data.position >= (dur - 1.5) then
            do_scrobble(data, os.time())
            has_scrobbled_current = true
        end
    end
end)

p:on("track.scrobble", function(track)
    if not lastfm_enabled() then return end

    local dur = get(cliamp.player.duration) or 0

    if not has_scrobbled_current and dur >= 30 then
        do_scrobble(track, os.time())
        has_scrobbled_current = true
    end
end)

-- Keybinding: * to love/unlove current track
local success, reason = p:bind("*", "Love current track on last.fm", function(key)
    love_track()
end)

if not success then
    cliamp.log.warn("last.fm: failed to bind * - " .. tostring(reason))
end

-- Keybinding: & to cycle last.fm mode
-- Normal -> Silence -> Deactivated -> Normal
local mode_success, mode_reason = p:bind("&", "Toggle last.fm mode", function(key)
    toggle_lastfm_mode()
end)

if not mode_success then
    cliamp.log.warn("last.fm: failed to bind & - " .. tostring(mode_reason))
end