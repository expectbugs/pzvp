-- PZVP — Video Player Window
-- ISCollapsableWindow with video display, controls, file picker, and quality selector.

require "PZFB/PZFBApi"
require "PZVP/PZVPPlayer"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local BUTTON_HGT = FONT_HGT_SMALL + 6

-- Quality presets: fraction of source resolution
local QUALITY_PRESETS = {
    {label = "Very Low", scale = 0.15, desc = "15% — best compatibility"},
    {label = "Low",      scale = 0.3,  desc = "30% — low-end PCs"},
    {label = "Medium",   scale = 0.5,  desc = "50% — good balance"},
    {label = "High",     scale = 0.8,  desc = "80% — high quality"},
    {label = "Max",      scale = 1.0,  desc = "100% — full source resolution"},
}

-- ============================================================
-- PZVPVideoPanel — renders the framebuffer with aspect ratio
-- ============================================================

PZVPVideoPanel = ISPanel:derive("PZVPVideoPanel")

function PZVPVideoPanel:new(x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.background = false
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    return o
end

function PZVPVideoPanel:prerender()
    self:drawRectStatic(0, 0, self.width, self.height, 1, 0, 0, 0)
end

function PZVPVideoPanel:render()
    ISPanel.render(self)

    local player = self.player
    if not player then return end

    player:update()

    if player.state == "STARTING" then
        self:drawText("Starting...", 10, self.height / 2 - 10, 1, 1, 1, 1, UIFont.Medium)
        return
    end

    if player.state == "BUFFERING" or player.state == "SEEKING" then
        self:drawText("Buffering...", 10, self.height / 2 - 10, 1, 1, 1, 1, UIFont.Medium)
        local count = PZFB.streamBufferCount()
        self:drawText(count .. " frames", 10, self.height / 2 + 10, 0.5, 0.5, 0.5, 1, UIFont.Small)
        return
    end

    if player.state == "IDLE" and player.errorMsg then
        self:drawText(tostring(player.errorMsg), 10, self.height / 2 - 10, 1, 0.4, 0.4, 1, UIFont.Small)
        return
    end

    if player.fb and PZFB.isReady(player.fb) and player.currentFrame >= 0 then
        local vidW = player.width
        local vidH = player.height
        local panW = self.width
        local panH = self.height

        local scaleX = panW / vidW
        local scaleY = panH / vidH
        local scale = scaleX
        if scaleY < scaleX then scale = scaleY end

        local drawW = math.floor(vidW * scale)
        local drawH = math.floor(vidH * scale)
        local drawX = math.floor((panW - drawW) / 2)
        local drawY = math.floor((panH - drawH) / 2)

        self:drawTextureScaled(PZFB.getTexture(player.fb), drawX, drawY, drawW, drawH, 1, 1, 1, 1)
    end
end

function PZVPVideoPanel:onMouseDown(x, y)
    if self.player and (self.player.state == "PLAYING" or self.player.state == "PAUSED" or self.player.state == "ENDED") then
        self.player:togglePlayPause()
        return true
    end
    return false
end

-- ============================================================
-- PZVPControlBar — play/pause, open, progress, time
-- ============================================================

PZVPControlBar = ISPanel:derive("PZVPControlBar")

function PZVPControlBar:new(x, y, w, h, player, window)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.window = window
    o.background = true
    o.backgroundColor = {r = 0.1, g = 0.1, b = 0.1, a = 0.9}
    o.borderColor = {r = 0.3, g = 0.3, b = 0.3, a = 1}
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = false
    o.anchorBottom = true
    return o
end

function PZVPControlBar:createChildren()
    ISPanel.createChildren(self)

    local btnW = 60
    local btnH = BUTTON_HGT
    local pad = 4
    local y = (self.height - btnH) / 2

    self.playBtn = ISButton:new(pad, y, btnW, btnH, "Play", self, PZVPControlBar.onPlayClick)
    self.playBtn:initialise()
    self.playBtn:instantiate()
    self:addChild(self.playBtn)

    self.openBtn = ISButton:new(pad + btnW + pad, y, btnW, btnH, "Open", self, PZVPControlBar.onOpenClick)
    self.openBtn:initialise()
    self.openBtn:instantiate()
    self:addChild(self.openBtn)

    self.progressX = pad + btnW + pad + btnW + pad + 14
end

function PZVPControlBar:onPlayClick(button)
    if self.player then
        self.player:togglePlayPause()
    end
end

function PZVPControlBar:onOpenClick(button)
    if self.player then
        self.player:stop()
    end
    if self.window then
        self.window:showFilePicker()
    end
end

function PZVPControlBar:render()
    ISPanel.render(self)

    local player = self.player
    if not player then return end

    if player.state == "PLAYING" then
        self.playBtn.title = "Pause"
    elseif player.state == "PAUSED" then
        self.playBtn.title = "Resume"
    else
        self.playBtn.title = "Play"
    end

    local barX = self.progressX
    local barH = 8
    local timeW = getTextManager():MeasureStringX(UIFont.Small, "00:00 / 00:00") + 10
    local barW = self.width - barX - timeW - 8
    local barY = (self.height - barH) / 2

    if barW > 20 then
        self:drawRectStatic(barX, barY, barW, barH, 0.6, 0.2, 0.2, 0.2)
        local progress = player:getProgress()
        if progress > 0 then
            self:drawRectStatic(barX, barY, barW * progress, barH, 1, 0.3, 0.6, 0.9)
        end
        self:drawRectBorderStatic(barX, barY, barW, barH, 0.8, 0.4, 0.4, 0.4)
    end

    local timeStr = player:getTimeString()
    local timeX = self.width - timeW
    local timeY = (self.height - FONT_HGT_SMALL) / 2
    self:drawText(timeStr, timeX, timeY, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function PZVPControlBar:onMouseDown(x, y)
    local player = self.player
    if not player or player.totalFrames <= 0 then return false end
    if player.state == "IDLE" or player.state == "STARTING" then return false end

    local timeW = getTextManager():MeasureStringX(UIFont.Small, "00:00 / 00:00") + 10
    local barX = self.progressX
    local barW = self.width - barX - timeW - 8
    local barH = 8
    local barY = (self.height - barH) / 2

    if x >= barX and x <= barX + barW and y >= barY - 4 and y <= barY + barH + 4 then
        local frac = (x - barX) / barW
        if frac < 0 then frac = 0 end
        if frac > 1 then frac = 1 end
        local timeSec = frac * player.duration
        player:seek(timeSec)
        return true
    end
    return false
end

-- ============================================================
-- PZVPFileList — simple file picker for ~/Zomboid/PZVP/
-- ============================================================

PZVPFileList = ISPanel:derive("PZVPFileList")

function PZVPFileList:new(x, y, w, h, onSelect)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.onSelect = onSelect
    o.files = {}
    o.background = false
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    return o
end

function PZVPFileList:refresh()
    self.files = {}
    local sep = getFileSeparator()
    local pzvpDir = Core.getMyDocumentFolder() .. sep .. "PZVP"
    local listing = PZFB.listDir(pzvpDir)
    if listing == "" then return end

    local start = 1
    local len = listing:len()
    while start <= len do
        local nl = listing:find("\n", start, true)
        local entry
        if nl then
            entry = listing:sub(start, nl - 1)
            start = nl + 1
        else
            entry = listing:sub(start)
            start = len + 1
        end
        local lower = entry:lower()
        if lower:match("%.mp4$") or lower:match("%.avi$") or lower:match("%.mkv$")
            or lower:match("%.webm$") or lower:match("%.mov$") or lower:match("%.flv$") then
            table.insert(self.files, entry)
        end
    end
end

function PZVPFileList:prerender()
    self:drawRectStatic(0, 0, self.width, self.height, 1, 0.05, 0.05, 0.08)
end

function PZVPFileList:render()
    ISPanel.render(self)

    local pad = 10
    local lineH = FONT_HGT_SMALL + 6

    self:drawText("Videos in ~/Zomboid/PZVP/", pad, pad, 0.8, 0.8, 0.8, 1, UIFont.Medium)

    if #self.files == 0 then
        self:drawText("No video files found.", pad, pad + FONT_HGT_MEDIUM + 10,
            0.5, 0.5, 0.5, 1, UIFont.Small)
        self:drawText("Drop .mp4/.avi/.mkv files into:", pad, pad + FONT_HGT_MEDIUM + 10 + lineH,
            0.5, 0.5, 0.5, 1, UIFont.Small)
        local pzvpDir = Core.getMyDocumentFolder() .. getFileSeparator() .. "PZVP" .. getFileSeparator()
        self:drawText(pzvpDir, pad, pad + FONT_HGT_MEDIUM + 10 + lineH * 2,
            0.4, 0.6, 0.8, 1, UIFont.Small)
        return
    end

    local startY = pad + FONT_HGT_MEDIUM + 10
    for i = 1, #self.files do
        local y = startY + (i - 1) * lineH
        if y + lineH > self.height then break end

        local mx = self:getMouseX()
        local my = self:getMouseY()
        if mx >= pad and mx <= self.width - pad and my >= y and my < y + lineH then
            self:drawRectStatic(pad, y, self.width - pad * 2, lineH, 0.3, 0.2, 0.3, 0.5)
        end

        self:drawText(self.files[i], pad + 4, y + 2, 1, 1, 1, 1, UIFont.Small)
    end
end

function PZVPFileList:onMouseDown(x, y)
    local pad = 10
    local lineH = FONT_HGT_SMALL + 6
    local startY = pad + FONT_HGT_MEDIUM + 10

    for i = 1, #self.files do
        local fy = startY + (i - 1) * lineH
        if y >= fy and y < fy + lineH and x >= pad and x <= self.width - pad then
            if self.onSelect then
                self.onSelect(self.files[i])
            end
            return true
        end
    end
    return false
end

-- ============================================================
-- PZVPQualityPicker — quality selection after choosing a video
-- ============================================================

PZVPQualityPicker = ISPanel:derive("PZVPQualityPicker")

function PZVPQualityPicker:new(x, y, w, h, filename, onSelect)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.filename = filename
    o.onSelect = onSelect
    o.background = false
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    return o
end

function PZVPQualityPicker:prerender()
    self:drawRectStatic(0, 0, self.width, self.height, 1, 0.05, 0.05, 0.08)
end

function PZVPQualityPicker:render()
    ISPanel.render(self)

    local pad = 10
    local lineH = BUTTON_HGT + 12

    self:drawText("Select Quality", pad, pad, 0.8, 0.8, 0.8, 1, UIFont.Medium)
    self:drawText(self.filename, pad, pad + FONT_HGT_MEDIUM + 4, 0.5, 0.7, 0.9, 1, UIFont.Small)

    local startY = pad + FONT_HGT_MEDIUM + 4 + FONT_HGT_SMALL + 14

    -- Measure widest label to align descriptions
    local maxLabelW = 0
    for i = 1, #QUALITY_PRESETS do
        local w = getTextManager():MeasureStringX(UIFont.Small, QUALITY_PRESETS[i].label)
        if w > maxLabelW then maxLabelW = w end
    end
    local descX = pad + 8 + maxLabelW + 16

    for i = 1, #QUALITY_PRESETS do
        local preset = QUALITY_PRESETS[i]
        local y = startY + (i - 1) * lineH

        local mx = self:getMouseX()
        local my = self:getMouseY()
        if mx >= pad and mx <= self.width - pad and my >= y and my < y + lineH - 4 then
            self:drawRectStatic(pad, y, self.width - pad * 2, lineH - 4, 0.4, 0.2, 0.3, 0.5)
        end

        self:drawText(preset.label, pad + 8, y + 4, 1, 1, 1, 1, UIFont.Small)
        self:drawText(preset.desc, descX, y + 4, 0.5, 0.5, 0.5, 1, UIFont.Small)
    end

    -- "If playback is choppy, click Open and choose a lower quality"
    local tipY = startY + #QUALITY_PRESETS * lineH + 8
    if tipY + FONT_HGT_SMALL < self.height then
        self:drawText("If playback is choppy, click Open and choose a lower setting.",
            pad, tipY, 0.4, 0.4, 0.4, 1, UIFont.Small)
    end
end

function PZVPQualityPicker:onMouseDown(x, y)
    local pad = 10
    local lineH = BUTTON_HGT + 12
    local startY = pad + FONT_HGT_MEDIUM + 4 + FONT_HGT_SMALL + 14

    for i = 1, #QUALITY_PRESETS do
        local fy = startY + (i - 1) * lineH
        if y >= fy and y < fy + lineH - 4 and x >= pad and x <= self.width - pad then
            if self.onSelect then
                self.onSelect(QUALITY_PRESETS[i])
            end
            return true
        end
    end
    return false
end

-- ============================================================
-- PZVPWindow — main window
-- ============================================================

PZVPWindow = ISCollapsableWindow:derive("PZVPWindow")
PZVPWindow.instance = nil

function PZVPWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Zomboid Video Player"
    o.resizable = true
    o.minimumWidth = 300
    o.minimumHeight = 250
    o.player = PZVPPlayer:new()
    o.selectedFile = nil
    return o
end

function PZVPWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local controlH = BUTTON_HGT + 12

    -- Video panel
    self.videoPanel = PZVPVideoPanel:new(0, th, self.width, self.height - th - controlH - rh, self.player)
    self.videoPanel:initialise()
    self:addChild(self.videoPanel)

    -- Control bar
    self.controlBar = PZVPControlBar:new(0, self.height - controlH - rh, self.width, controlH, self.player, self)
    self.controlBar:initialise()
    self:addChild(self.controlBar)

    -- File list
    self.fileList = PZVPFileList:new(0, th, self.width, self.height - th - rh,
        function(filename) self:onFileSelected(filename) end)
    self.fileList:initialise()
    self:addChild(self.fileList)
    self.fileList:refresh()

    -- Quality picker (hidden initially)
    self.qualityPicker = PZVPQualityPicker:new(0, th, self.width, self.height - th - rh, "",
        function(preset) self:onQualitySelected(preset) end)
    self.qualityPicker:initialise()
    self:addChild(self.qualityPicker)

    self:showFilePicker()

    -- CRITICAL: resize widgets must be on top
    self.resizeWidget:bringToTop()
    self.resizeWidget2:bringToTop()
end

function PZVPWindow:showFilePicker()
    self.fileList:setVisible(true)
    self.fileList:refresh()
    self.qualityPicker:setVisible(false)
    self.videoPanel:setVisible(false)
    self.controlBar:setVisible(false)
end

function PZVPWindow:showQualityPicker(filename)
    self.selectedFile = filename
    self.qualityPicker.filename = filename
    self.fileList:setVisible(false)
    self.qualityPicker:setVisible(true)
    self.videoPanel:setVisible(false)
    self.controlBar:setVisible(false)
end

function PZVPWindow:showPlayer()
    self.fileList:setVisible(false)
    self.qualityPicker:setVisible(false)
    self.videoPanel:setVisible(true)
    self.controlBar:setVisible(true)
end

function PZVPWindow:onFileSelected(filename)
    if not PZFB.ffmpegAvailable() then
        self.player.errorMsg = "ffmpeg not found. Install ffmpeg and restart."
        self:showPlayer()
        return
    end
    self:showQualityPicker(filename)
end

function PZVPWindow:onQualitySelected(preset)
    local sep = getFileSeparator()
    local pzvpDir = Core.getMyDocumentFolder() .. sep .. "PZVP"
    local inputPath = pzvpDir .. sep .. self.selectedFile

    self:showPlayer()
    self.player:startVideo(inputPath, preset.scale)
end

function PZVPWindow:close()
    if self.player then
        self.player:stop()
    end
    self:setVisible(false)
    self:removeFromUIManager()
    PZVPWindow.instance = nil
end

function PZVPWindow.open()
    if PZVPWindow.instance then
        PZVPWindow.instance:close()
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w = 500
    local h = 400
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local window = PZVPWindow:new(x, y, w, h)
    window:initialise()
    window:instantiate()
    window:setVisible(true)
    window:addToUIManager()

    PZVPWindow.instance = window
    return window
end
