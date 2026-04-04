-- PZVP — Streaming Video Playback Engine
-- Uses PZFB streaming API: ffmpeg pipes frames to in-memory ring buffer.

require "PZFB/PZFBApi"

PZVPPlayer = {}
PZVPPlayer.__index = PZVPPlayer

function PZVPPlayer:new()
    local o = setmetatable({}, self)
    o.state = "IDLE"       -- IDLE | STARTING | BUFFERING | PLAYING | PAUSED | SEEKING | ENDED
    o.fb = nil             -- PZFB framebuffer handle
    o.inputPath = nil      -- original video file path
    o.width = 0
    o.height = 0
    o.fps = 24
    o.duration = 0         -- total duration in seconds
    o.totalFrames = 0
    o.currentFrame = -1    -- last rendered frame index
    o.startTime = 0        -- getTimestampMs() when playback started/resumed
    o.frameOffset = 0      -- frame offset for resume-after-pause
    o.errorMsg = nil
    o.audioLoaded = false
    o.audioStarted = false
    o.audioReloaded = false -- true after reload with complete file (seeking works)
    return o
end

--- Start streaming a video file.
function PZVPPlayer:startVideo(inputPath, qualityScale)
    self:stop()
    self.inputPath = inputPath
    self.errorMsg = nil
    PZFB.streamStart(inputPath, qualityScale, 120)
    self.state = "STARTING"
end

--- Start playback from current frameOffset.
function PZVPPlayer:play()
    if self.state ~= "BUFFERING" and self.state ~= "SEEKING" and self.state ~= "ENDED" then return end
    if self.state == "ENDED" then
        self.frameOffset = 0
        self.currentFrame = -1
        PZFB.streamSeek(0)
        self.state = "SEEKING"
        return
    end
    -- Start audio at the correct position
    if self.audioLoaded then
        local posMs = math.floor(self.frameOffset * 1000 / self.fps)
        PZFB.audioPlayFrom(posMs)
        self.audioStarted = true
    end
    -- Set startTime AFTER audio starts so video timer matches audio start
    self.startTime = getTimestampMs()
    self.state = "PLAYING"
end

--- Pause playback.
function PZVPPlayer:pause()
    if self.state ~= "PLAYING" then return end
    self.frameOffset = self.currentFrame
    if self.audioStarted then
        PZFB.audioPause()
    end
    self.state = "PAUSED"
end

--- Resume from pause.
function PZVPPlayer:resume()
    if self.state ~= "PAUSED" then return end
    if self.audioLoaded then
        local posMs = math.floor(self.frameOffset * 1000 / self.fps)
        PZFB.audioPlayFrom(posMs)
        self.audioStarted = true
    end
    -- Set startTime AFTER audio starts
    self.startTime = getTimestampMs()
    self.state = "PLAYING"
end

--- Toggle play/pause.
function PZVPPlayer:togglePlayPause()
    if self.state == "PLAYING" then
        self:pause()
    elseif self.state == "PAUSED" then
        self:resume()
    elseif self.state == "BUFFERING" or self.state == "ENDED" then
        self:play()
    end
end

--- Seek to a time in seconds.
function PZVPPlayer:seek(timeSec)
    if self.state == "IDLE" or self.state == "STARTING" then return end
    if timeSec < 0 then timeSec = 0 end
    if self.duration > 0 and timeSec > self.duration then timeSec = self.duration end

    self.frameOffset = math.floor(timeSec * self.fps)
    self.currentFrame = -1

    -- Pause audio — play() will restart at correct position after rebuffer
    if self.audioStarted then
        PZFB.audioPause()
    end

    PZFB.streamSeek(timeSec)
    self.state = "SEEKING"
end

--- Stop playback and release all resources.
function PZVPPlayer:stop()
    PZFB.audioStop()
    PZFB.streamStop()
    if self.fb then
        PZFB.destroy(self.fb)
        self.fb = nil
    end
    self.currentFrame = -1
    self.frameOffset = 0
    self.audioLoaded = false
    self.audioStarted = false
    self.audioReloaded = false
    self.state = "IDLE"
end

--- Update — call every frame from render().
function PZVPPlayer:update()
    if self.state == "STARTING" then
        local s = PZFB.streamStatus()
        if s >= 2 then
            self.width = PZFB.streamWidth()
            self.height = PZFB.streamHeight()
            self.fps = PZFB.streamFps()
            self.duration = PZFB.streamDuration()
            self.totalFrames = PZFB.streamTotalFrames()
            if self.width > 0 and self.height > 0 then
                self.fb = PZFB.createLinear(self.width, self.height)
                self.state = "BUFFERING"
            end
        elseif s == 5 then
            self.errorMsg = PZFB.streamError()
            self:stop()
        end
        return
    end

    if self.state == "BUFFERING" or self.state == "SEEKING" then
        local s = PZFB.streamStatus()
        if s >= 3 then
            if not self.audioLoaded and PZFB.streamAudioReady() then
                local audioPath = PZFB.streamAudioPath()
                if audioPath ~= "" then
                    PZFB.audioLoad(audioPath)
                    self.audioLoaded = true
                end
            end
            self:play()
        elseif s == 5 then
            self.errorMsg = PZFB.streamError()
            self:stop()
        end
        return
    end

    -- Load audio if not yet loaded (may become ready during playback)
    if not self.audioLoaded and PZFB.streamAudioReady() then
        local audioPath = PZFB.streamAudioPath()
        if audioPath ~= "" then
            PZFB.audioLoad(audioPath)
            self.audioLoaded = true
            local posMs = 0
            if self.currentFrame > 0 then
                posMs = math.floor(self.currentFrame * 1000 / self.fps)
            end
            PZFB.audioPlayFrom(posMs)
            self.audioStarted = true
            -- Re-sync video timer to match audio start
            self.frameOffset = self.currentFrame
            self.startTime = getTimestampMs()
        end
    end

    -- Reload audio once extraction is complete (enables seeking to full duration)
    if self.audioLoaded and not self.audioReloaded and PZFB.streamAudioDone() then
        self.audioReloaded = true
        -- Remember current position
        local posMs = 0
        if self.currentFrame > 0 then
            posMs = math.floor(self.currentFrame * 1000 / self.fps)
        end
        -- Reload from complete file
        local audioPath = PZFB.streamAudioPath()
        if audioPath ~= "" then
            PZFB.audioLoad(audioPath)
            PZFB.audioPlayFrom(posMs)
            self.audioStarted = true
            -- Re-sync video timer
            self.frameOffset = self.currentFrame
            self.startTime = getTimestampMs()
            print("[PZVP] Audio reloaded (full file). len=" .. tostring(PZFB.audioGetLength()) .. "ms")
        end
    end

    if self.state ~= "PLAYING" then return end
    if not self.fb or not PZFB.isReady(self.fb) then return end

    local elapsed = getTimestampMs() - self.startTime
    local targetFrame = self.frameOffset + math.floor(elapsed * self.fps / 1000)

    if targetFrame >= self.totalFrames and self.totalFrames > 0 then
        targetFrame = self.totalFrames - 1
        self.state = "ENDED"
        if self.audioStarted then
            PZFB.audioPause()
        end
    end

    if targetFrame ~= self.currentFrame and targetFrame >= 0 then
        if PZFB.streamFrame(self.fb, targetFrame) then
            self.currentFrame = targetFrame
        end
    end
end

--- Get progress as a fraction (0.0 to 1.0).
function PZVPPlayer:getProgress()
    if self.totalFrames <= 1 then return 0 end
    if self.currentFrame < 0 then return 0 end
    return self.currentFrame / (self.totalFrames - 1)
end

--- Format current time as "M:SS / M:SS".
function PZVPPlayer:getTimeString()
    local cur = 0
    if self.currentFrame >= 0 and self.fps > 0 then
        cur = self.currentFrame / self.fps
    end
    local total = self.duration
    if total <= 0 and self.totalFrames > 0 and self.fps > 0 then
        total = self.totalFrames / self.fps
    end
    local function fmt(s)
        local m = math.floor(s / 60)
        local sec = math.floor(s) - m * 60
        if sec < 10 then
            return m .. ":0" .. sec
        else
            return m .. ":" .. sec
        end
    end
    return fmt(cur) .. " / " .. fmt(total)
end
