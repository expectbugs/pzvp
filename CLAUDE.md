# PZVP — Project Zomboid Video Player: Development Rules

## RULE ZERO: Verify Before Execute

***NEVER run commands based on guesses or assumptions. Before any PZ Lua API call, read the actual PZ source for correct function signatures. Before any Java class modification, verify the method exists and its signature matches. Before any GL call, verify the constant values. One correct approach beats three failed attempts.***

***NEVER GUESS. ALWAYS VERIFY. ALWAYS check the real source.***

## Critical: Source Code Verification

- **B42 client source (AUTHORITATIVE):** `/home/user/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/media/lua/`
- **PZ Java jar:** `/home/user/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/projectzomboid.jar`
- **DO NOT USE the Dedicated Server source** at `/opt/steamcmd/` — it is STALE, OUTDATED, and WRONG for Build 42.
- **Verified Workshop mods** at: `/home/user/.local/share/Steam/steamapps/workshop/content/108600/`

## System Environment

- **Machine:** beardos — Gentoo Linux, OpenRC, RTX 3090, 32GB RAM
- **Python 3.13** — use `./venv/bin/python` (no system pip)
- **Java 25 JDK:** `/usr/lib64/openjdk-25/bin/javac` and `/usr/lib64/openjdk-25/bin/java`
- **Java 21 JDK (system default):** `/usr/bin/javac` — DO NOT USE for PZ compilation
- **FFmpeg:** available as `ffmpeg` on PATH
- **PZ Install:** `/home/user/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/`
- **PZFB project:** `~/pzfb/` — the framebuffer library this mod depends on

## What This Project Is

A Project Zomboid mod that lets players play local video files in-game using PZFB (Video Framebuffer) as a dependency. The video displays in a resizable, movable PZ UI window with play/pause, restart, and seek controls.

## Architecture Overview

```
[Video File] → [ffmpeg converter] → [video.raw + audio.ogg]
                                          ↓            ↓
                                    fbLoadRawFrame   PZ Sound Bank
                                          ↓            ↓
                                    [PZFB Texture]  [BaseSoundEmitter]
                                          ↓            ↓
                                    [ISCollapsableWindow with controls]
```

### Video Pipeline
1. **Conversion (external, before playback):** `ffmpeg` converts any video to raw RGBA frames in one big file + extracts audio to .ogg
2. **Frame loading:** A new Java method `fbLoadRawFrame(tex, path, frameIndex)` reads `w*h*4` bytes at offset `frameIndex * w * h * 4` from the raw file
3. **Playback:** Lua increments frame counter each tick, calls `fbLoadRawFrame` to update the texture
4. **Display:** `drawTextureScaled()` renders the texture in a UI panel

### Audio Pipeline
PZ uses FMOD via a registered sound bank system. Audio files MUST be registered in script files before playback.

## PZFB Dependency — Complete API Reference

PZFB (Video Framebuffer, Workshop ID 3698742271) provides pixel-level framebuffer rendering.

### How PZFB Works
A patched `zombie.core.Color` class adds static methods for framebuffer operations. All GL calls are dispatched to PZ's render thread via `RenderThread.queueInvokeOnRenderContext()`. The patched class files must be deployed to the PZ install directory via install scripts.

### Lua API (require "PZFB/PZFBApi")

```lua
PZFB.isAvailable()                    -- boolean: class files deployed?
PZFB.create(width, height)            -- fb handle table (NEAREST filtering)
PZFB.createLinear(width, height)      -- fb handle table (LINEAR filtering, better for video)
PZFB.isReady(fb)                      -- boolean: GL texture allocated?
PZFB.fill(fb, r, g, b, a)            -- fill solid color (0-255 each)
PZFB.loadRaw(fb, path)               -- load raw RGBA file (w*h*4 bytes, no header)
PZFB.getTexture(fb)                   -- get PZ Texture for drawTextureScaled()
PZFB.destroy(fb)                      -- free GL resources
PZFB.getVersion()                     -- version string
```

### Low-level Java API (Color.fb* static methods)
```lua
Color.fbCreate(width, height)          -- Texture (NEAREST)
Color.fbCreateLinear(width, height)    -- Texture (LINEAR)
Color.fbIsReady(tex)                   -- boolean (per-texture)
Color.fbFill(tex, r, g, b, a)         -- fill solid color
Color.fbLoadRaw(tex, path)            -- load raw RGBA file
Color.fbDestroy(tex)                   -- free resources
Color.fbPing()                         -- "PZFB 1.0.0"
Color.fbVersion()                      -- "1.0.0"
```

### Drawing the framebuffer in a UI panel
```lua
function MyPanel:render()
    ISPanel.render(self)
    if fb and PZFB.isReady(fb) then
        self:drawTextureScaled(PZFB.getTexture(fb), x, y, w, h, 1, 1, 1, 1)
    end
end
```

## New Java Method Needed: fbLoadRawFrame

**This must be added to PZFB's Color.java** (`~/pzfb/java/zombie/core/Color.java`).

The existing `fbLoadRaw` reads an entire file that must be exactly `w*h*4` bytes. For video, we need to read one frame from a concatenated raw file.

### Proposed signature:
```java
public static boolean fbLoadRawFrame(zombie.core.textures.Texture tex, String path, int frameIndex)
```

### Implementation:
- Open file with `RandomAccessFile`
- Seek to `frameIndex * width * height * 4`
- Read `width * height * 4` bytes into a fresh `ByteBuffer`
- Queue `glTexSubImage2D` on render thread (same pattern as `fbLoadRaw`)
- Return false if offset is beyond file size (end of video)

### Key details:
- Use `RandomAccessFile` for seeking, NOT `Files.readAllBytes` (which reads the whole file)
- Allocate a fresh ByteBuffer per call (copy-on-queue thread safety, same as fbFill/fbLoadRaw)
- Get width/height from `tex.getWidth()` / `tex.getHeight()` (public methods)
- Get GL id from `tex.getTextureId().getID()` (public method, no reflection needed)
- Frame count can be computed in Lua: `fileSize / (width * height * 4)` — but Lua sandbox has no `io.*`. Options: compute in Java and expose, or pass file size from the converter tool.

### Also add to Color.java:
```java
public static int fbFileSize(String path)
```
Returns file size in bytes, or -1 if file doesn't exist. Lua can then calculate total frames.

### After modifying Color.java:
```bash
cd ~/pzfb
./build.sh --deploy   # Recompile + deploy to PZ install
```
The anonymous inner class count may change — ALL Color*.class files must be redeployed.

### Also update PZFB's Lua API:
Add `PZFB.loadRawFrame(fb, path, frameIndex)` and `PZFB.fileSize(path)` wrappers in `~/pzfb/mod/PZFB/42/media/lua/client/PZFB/PZFBApi.lua`.

## Video Conversion Pipeline

### Convert video to raw RGBA frames:
```bash
ffmpeg -i input.mp4 -vf scale=320:240 -pix_fmt rgba -f rawvideo output.raw
```

### Extract audio:
```bash
ffmpeg -i input.mp4 -vn -acodec libvorbis -q:a 5 output.ogg
```

### Both in one script:
```bash
#!/bin/bash
# tools/convert.sh <input_video> <output_dir> [width] [height]
INPUT="$1"
OUTDIR="$2"
W="${3:-320}"
H="${4:-240}"
mkdir -p "$OUTDIR"
ffmpeg -i "$INPUT" -vf "scale=${W}:${H}" -pix_fmt rgba -f rawvideo "$OUTDIR/video.raw"
ffmpeg -i "$INPUT" -vn -acodec libvorbis -q:a 5 "$OUTDIR/audio.ogg"
# Write metadata
FRAMES=$(( $(stat -c%s "$OUTDIR/video.raw") / ($W * $H * 4) ))
FPS=$(ffprobe -v 0 -select_streams v -of csv=p=0 -show_entries stream=r_frame_rate "$INPUT" | head -1)
echo "width=$W" > "$OUTDIR/meta.txt"
echo "height=$H" >> "$OUTDIR/meta.txt"
echo "frames=$FRAMES" >> "$OUTDIR/meta.txt"
echo "fps=$FPS" >> "$OUTDIR/meta.txt"
```

### File sizes to expect:
| Resolution | Per frame | 30s @ 24fps | 5min @ 24fps |
|-----------|-----------|-------------|--------------|
| 160x120   | 76.8 KB   | 55 MB       | 553 MB       |
| 320x240   | 307 KB    | 221 MB      | 2.2 GB       |
| 256x192   | 196 KB    | 141 MB      | 1.4 GB       |

Recommend 160x120 or 256x192 for reasonable file sizes. 320x240 works but uses significant disk space for longer videos.

## PZ Audio System (Verified)

### How it works
PZ uses FMOD. All sounds MUST be registered in sound bank script files before playback. Mods CANNOT play arbitrary audio files from absolute paths.

### Sound registration (required):
Create a file at `mod/PZVP/42/media/scripts/PZVP_Sounds.txt`:
```
module PZVP
{
    sound PZVP_Audio
    {
        category = Item,
        master = Ambient,
        clip
        {
            file = media/sound/PZVP/audio.ogg,
            distanceMax = 50,
        }
    }
}
```

### Playback from Lua:
```lua
-- Get the player's sound emitter
local emitter = getSpecificPlayer(0):getEmitter()

-- Play a registered sound (returns a handle for control)
local handle = emitter:playSoundImpl("PZVP_Audio", nil)

-- Control volume (0.0 to 1.0)
emitter:setVolume(handle, 0.8)

-- Stop playback
emitter:stopSound(handle)

-- Stop all sounds from this emitter
emitter:stopAll()
```

### Limitations (verified from PZ source and TrueMusic mod):
- **No seek/skip** — FMOD API is not exposed for seeking through PZ's Lua bindings
- **No true pause/resume** — can only stop; resuming restarts from the beginning
- **No arbitrary file paths** — must be registered in sound bank and placed in mod's media/sound/ directory
- **Registration is static** — sound bank scripts are loaded at game start, not dynamically

### What this means for the video player:
- Audio sync is **start-together-and-hope** — start video frames and audio at the same time
- **Pause = stop both** — on resume, restart both from the beginning (or skip audio and just resume video silently)
- **Seek is video-only** — can seek video frames freely but audio restarts from beginning
- **Each video needs its audio registered** — the .ogg must be in the mod's media/sound/ directory with a matching script entry

### Pragmatic approach for v1:
- Play video + audio together from the start
- Pause stops both; resume restarts both from frame 0 (simplest correct behavior)
- Seek bar controls video only; audio restarts on seek (or stops)
- Users convert videos with the provided tool, which places files in the right locations

### Future: Java-side audio
For proper pause/seek, add FMOD calls to Color.java (or another patched class). FMOD is accessible from Java via LWJGL. This is out of scope for v1.

## PZ UI Patterns (Verified — Learn from PZFB's mistakes)

### ISCollapsableWindow (resizable, movable window)
```lua
local window = ISCollapsableWindow:new(x, y, width, height)
window.minimumWidth = 200
window.minimumHeight = 150
window:initialise()
window:instantiate()  -- REQUIRED: creates Java object, calls createChildren()
window:setTitle("Video Player")
window:setResizable(true)

-- Add child content AFTER initialise/instantiate
local th = window:titleBarHeight()
local rh = window:resizeWidgetHeight()
local inner = MyPanel:new(0, th, window:getWidth(), window:getHeight() - th - rh)
inner:initialise()
inner:instantiate()
inner.anchorLeft = true    -- These must be set BEFORE instantiate
inner.anchorRight = true   -- or in the :new() constructor
inner.anchorTop = true
inner.anchorBottom = true
window:addChild(inner)

-- CRITICAL: bring resize widgets to top after adding children
-- otherwise child panels eat mouse events meant for resize handles
window.resizeWidget:bringToTop()
window.resizeWidget2:bringToTop()

window:addToUIManager()
```

### Key facts about ISCollapsableWindow:
- `initialise()` only sets up children table and ID — does NOT create Java object
- `instantiate()` creates the Java UIElement, sets anchors, calls `createChildren()`
- `createChildren()` is where resize widgets, close button, etc. are created
- `addChild()` auto-calls `instantiate()` on the child if not already done
- Anchor properties (`anchorLeft/Right/Top/Bottom`) must be set before `instantiate()` to take effect on the Java side
- After adding children, call `resizeWidget:bringToTop()` and `resizeWidget2:bringToTop()` or the children will intercept resize drag events
- `titleBarHeight()` returns the title bar height — content starts below this
- `resizeWidgetHeight()` returns the bottom resize bar height — content should not overlap this
- `window.close` can be overridden to add cleanup logic

### ISButton (for play/pause, restart controls):
```lua
local btn = ISButton:new(x, y, width, height, "Play", self, self.onPlayClick)
btn:initialise()
btn:instantiate()
parent:addChild(btn)
```

### Input capture (PZFBInputPanel):
```lua
require "PZFB/PZFBInput"
-- PZFBInputPanel is an ISPanel subclass that captures keyboard
-- grabInput() / releaseInput() / isKeyDown(key) / onPZFBKeyPress(key)
-- Uses isKeyConsumed() + GameKeyboard.eatKeyPress() pattern
```

## B42 Mod Structure (Verified)

```
mod/PZVP/
├── common/                    # Required empty dir
│   └── .gitkeep
└── 42/
    ├── mod.info               # MUST be in 42/, NOT mod root
    ├── poster.png             # MUST be in 42/, NOT mod root
    ├── icon.png               # MUST be in 42/, NOT mod root
    ├── media/
    │   ├── lua/
    │   │   └── client/
    │   │       └── PZVP/
    │   │           └── *.lua
    │   ├── scripts/
    │   │   └── PZVP_Sounds.txt    # Sound bank registrations
    │   └── sound/
    │       └── PZVP/
    │           └── audio.ogg      # Audio files
    └── (no mod.info at mod root!)
```

### mod.info format:
```
name=Video Player
id=PZVP
require=PZFB
description=Play local video files in Project Zomboid.
poster=poster.png
icon=icon.png
modversion=1.0.0
versionMin=42.0
```

### Symlink to PZ mods directory for testing:
```bash
ln -s ~/pzvp/mod/PZVP ~/Zomboid/mods/PZVP
```

## B42 PZ Lua Sandbox Limitations

- **No `io.*` or `os.*` modules.** Lua is sandboxed.
- **No `next()`, `rawget(table, number)`, `string.byte()`, `math.huge`** — Kahlua VM limitations.
- **File I/O:** `getFileWriter(filename, createIfNull, append)` and `getFileReader(filename, createIfNull)` write to `~/Zomboid/Lua/` only.
- **Events:** `Events.OnTick`, `Events.OnGameStart`, `Events.OnKeyPressed`
- **Cannot run external processes** — ffmpeg conversion must happen outside PZ.

## Project Structure

```
~/pzvp/
├── CLAUDE.md              # This file
├── README.md
├── CHANGELOG.md
├── LICENSE
├── tools/
│   └── convert.sh         # FFmpeg video converter script
└── mod/
    └── PZVP/
        ├── common/
        │   └── .gitkeep
        └── 42/
            ├── mod.info
            ├── poster.png
            ├── icon.png
            └── media/
                ├── lua/client/PZVP/
                │   ├── PZVPMain.lua        # Main entry point
                │   ├── PZVPPlayer.lua       # Video playback logic
                │   └── PZVPWindow.lua       # UI window with controls
                ├── scripts/
                │   └── PZVP_Sounds.txt      # Sound bank registrations
                └── sound/PZVP/
                    └── (user audio files go here)
```

## Implementation Plan

### Phase 1: Add fbLoadRawFrame to PZFB
1. Add `fbLoadRawFrame(Texture, String, int)` and `fbFileSize(String)` to `~/pzfb/java/zombie/core/Color.java`
2. Add Lua wrappers to `~/pzfb/mod/PZFB/42/media/lua/client/PZFB/PZFBApi.lua`
3. Recompile and deploy: `cd ~/pzfb && ./build.sh --deploy`

### Phase 2: Converter tool
1. Create `tools/convert.sh` — wraps ffmpeg to produce video.raw + audio.ogg + meta.txt
2. Output goes to a user-specified directory (or `~/Zomboid/Lua/PZVP/`)

### Phase 3: Video player UI
1. ISCollapsableWindow with framebuffer display panel
2. Bottom control bar: play/pause button, restart button, frame counter/progress bar
3. Key bindings: INSERT to open file picker / player window, END to close
4. Frame advancement: increment frame counter in OnTick or render(), call fbLoadRawFrame

### Phase 4: Audio integration
1. Sound bank script for registered audio
2. Start audio playback simultaneously with video
3. Handle pause/stop/restart (with known limitations)

## User Profile

- **Name:** Adam (expectbugs)
- **System:** Gentoo Linux, OpenRC, XFCE4 desktop, RTX 3090, 32GB RAM, 4K display
- **Communication style:** Direct, casual, moves fast. Don't over-explain.
- **Key rule:** NEVER GUESS. Always verify against real source code.
