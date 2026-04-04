-- PZVP — Video Player: Main Entry Point

require "PZFB/PZFBApi"
require "PZVP/PZVPWindow"

-- Disable PZFB's test key bindings — we take over INSERT/END
PZFB = PZFB or {}
PZFB.TEST_DISABLED = true

local PZVP_INITIALIZED = false

local function onGameStart()
    if PZVP_INITIALIZED then return end
    PZVP_INITIALIZED = true

    if not PZFB.isAvailable() then
        print("[PZVP] ERROR: PZFB not available. Install PZFB class files and restart.")
        return
    end

    print("[PZVP] Zomboid Video Player loaded. PZFB v" .. tostring(PZFB.getVersion()))

    if PZFB.ffmpegAvailable() then
        print("[PZVP] ffmpeg detected.")
    else
        print("[PZVP] WARNING: ffmpeg not found. Video playback requires ffmpeg.")
    end
end

local function onKeyPressed(key)
    if not PZFB.isAvailable() then return end

    if key == Keyboard.KEY_INSERT then
        if not PZVPWindow.instance or not PZVPWindow.instance:isVisible() then
            PZVPWindow.open()
        end
    elseif key == Keyboard.KEY_END then
        if PZVPWindow.instance and PZVPWindow.instance:isVisible() then
            PZVPWindow.instance:close()
        end
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnKeyPressed.Add(onKeyPressed)
