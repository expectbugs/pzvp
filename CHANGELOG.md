# Changelog

## 1.1.0 (2026-10-15)

Works with PZFB 1.7.x (legacy behaviour); **PZFB 1.8.0 recommended**. No new features — this release makes PZVP a good neighbour to the other PZFB mods and cleans up leftovers.

- **Fixed:** closing the player or pressing **Open** stops only PZVP's own stream and audio. PZVP keeps the session id PZFB 1.8 returns from `streamStart`, calls `streamStop(id)` only if it started a stream and `audioStop()` only if it loaded audio, and checks `ownsSession(id)` before trusting PZFB's global status. Before, closing PZVP could null PZFB's shared buffer under a running PZEMU game ("Game read error"), and pressing Open while PZEMU/PZDOOM ran killed their process.
- **Added:** when another PZFB mod takes over the shared slot while a video plays, PZVP shows *"Playback stopped: another mod took over PZFB's video slot."* and releases its side instead of displaying the other mod's frames. (`streamSeek()` is global, so seek/replay are also gated on ownership.)
- **Fixed:** the video panel's input listeners are released on window close — `PZVPWindow:close()` tears down the input panel (`cleanup()` on PZFB 1.8, the panel's own `close()` on 1.7.x) before removing the window.
- **Removed:** five dead `captureKey()` registrations (the panel runs in FOCUS mode, which ignores them) and `tools/convert.sh` (pre-streaming design: it pre-rendered `video.raw` + `audio.ogg` + `meta.txt` for an `fbLoadRawFrame` player that never shipped, and printed "Press F7"; nothing in PZVP 1.x reads its output).
- **Verified against PZ 42.21** (static check of every PZ and PZFB API PZVP uses; in-game confirmation is the Workshop user's "still working?" answer).
- Internal dev notes (`CLAUDE.md`) rewritten for the streaming design.

## 1.0.0 (2026-04-03; Workshop updates through 2026-04-10)

Initial release — the first video player for Project Zomboid Build 42.

- Stream any video file (MP4, MKV, AVI, WebM, MOV, FLV) from `Zomboid/PZVP/` through ffmpeg into PZFB's in-memory ring buffer — no temp video files.
- Audio with full seek support: the track is extracted to a temporary WAV and played through FMOD directly; the WAV is reloaded once extraction finishes so seeking past the initially-known length works.
- Quality picker (Very Low 15 % → Max 100 % of source resolution).
- Play, pause, resume, seek via the progress bar; click the video to pause/resume.
- Aspect-ratio-correct display with letterboxing in a resizable, movable window.
- INSERT opens the player, END closes it; sets `PZFB.TEST_DISABLED` so PZFB's test window stays out of the way.
- Pressure-vessel (Steam Linux Runtime) support via PZFB.
- 2026-04-05: integrated PZFB Input System v2.0 (`PZFBInputPanel`); 2026-04-06: input mode switched from SELECTIVE to FOCUS — keys only go to the player while the mouse is over the video (SPACE, ←/→, ↑/↓).
