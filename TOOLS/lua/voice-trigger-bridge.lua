local mp = require("mp")
local options = require("mp.options")
local utils = require("mp.utils")

local o = {
    trigger_file = "~~temp/mpv_voice_trigger/trigger.json",
    poll_interval = 0.25,
    show_osd = true,
    forward_script_message = "screenshot-folder-trigger",
    enable_debug = false,
}

options.read_options(o, "voice-trigger-bridge")

local last_payload = ""

local function notify(msg)
    if o.show_osd then
        mp.osd_message(msg, 1.5)
    end
end

local function log(msg)
    if o.enable_debug then
        mp.msg.info("[voice-trigger-bridge] " .. msg)
    end
end

local function resolve_path(path)
    local expanded = mp.command_native({"expand-path", path})
    return mp.command_native({"normalize-path", expanded})
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function poll_trigger_file()
    local trigger_path = resolve_path(o.trigger_file)
    local fi = utils.file_info(trigger_path)
    if not fi or not fi.is_file then
        return
    end

    local content = read_file(trigger_path)
    if not content or content == "" then
        return
    end

    if content == last_payload then
        return
    end

    last_payload = content
    local payload = utils.parse_json(content) or {}
    local phrase = payload.phrase or "voice"
    log("trigger phrase=" .. phrase)

    mp.commandv("script-message-to", "screenshot-folder", o.forward_script_message)
    mp.commandv("script-message", o.forward_script_message)
    notify("Voice trigger: " .. phrase)
end

local timer = mp.add_periodic_timer(o.poll_interval, poll_trigger_file)
timer:resume()

mp.register_script_message("voice-trigger-bridge-test", function()
    notify("Voice bridge test")
    mp.commandv("script-message-to", "screenshot-folder", o.forward_script_message)
    mp.commandv("script-message", o.forward_script_message)
end)

log("loaded; trigger_file=" .. resolve_path(o.trigger_file))
