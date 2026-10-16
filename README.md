# Zomboid Video Player

Watch local video files inside Project Zomboid. The first-ever video player mod for PZ.

Drop any video file into a folder, press INSERT in-game, pick your video and quality setting, and watch — complete with audio, seeking, and pause/resume.

## Requirements

- **Project Zomboid** Build 42 (checked against 42.21)
- **[Video Framebuffer (PZFB)](https://steamcommunity.com/sharedfiles/filedetails/?id=3698742271)** — install from Workshop, then do its one-time extra step (a setup panel on the main menu points you to the install script; full guide in PZFB's `docs/INSTALL.md`). **PZFB 1.8.0 or newer recommended** — PZVP works with 1.7.x, but closing the player could stop another PZFB mod's game there.
- **ffmpeg** — must be installed on your system and available on PATH
  - **Linux:** `sudo apt install ffmpeg` (Ubuntu/Debian) or your distro's package manager
  - **Windows:** Download from [ffmpeg.org](https://ffmpeg.org/download.html), extract, and add to PATH

## How to Use

### 1. Place your videos

Put video files (.mp4, .mkv, .avi, .webm, .mov, .flv) into:

- **Linux:** `~/Zomboid/PZVP/`
- **Windows:** `C:\Users\YourName\Zomboid\PZVP\`

Create the `PZVP` folder if it doesn't exist.

### 2. Open the player

Press **INSERT** in-game to open the Zomboid Video Player. Press **END** to close it.

### 3. Pick a video and quality

Select your video from the list, then choose a quality setting:

| Quality | Resolution | Notes |
|---------|-----------|-------|
| Very Low | 15% of source | Best compatibility, any PC |
| Low | 30% of source | Low-end PCs |
| Medium | 50% of source | Good balance |
| High | 80% of source | High quality |
| Max | 100% of source | Full resolution — if your PC can handle it |

If playback is choppy, click **Open**, select the same video, and choose a lower quality.

### 4. Controls

- **Click the video** to pause/resume
- **Play/Pause button** in the control bar
- **Seek bar** — click anywhere to jump to that position
- **Open button** — stop playback and return to the video list
- **Keyboard, while the mouse is over the video:** SPACE play/pause, ←/→ seek 5 s, ↑/↓ volume (full / quiet). Move the mouse off the video and your keys go back to the game.

## How It Works

- Video is streamed in real-time: ffmpeg decodes frames and pipes them to an in-memory buffer. No massive temp files.
- Audio is extracted to a temporary WAV file (deleted when you stop playback). Audio seeking works after the extraction completes (~2-10 seconds depending on video length).
- All processing happens locally. No network, no uploads, no external services.
- PZVP, PZEMU and PZDOOM share one PZFB video slot. Starting one stops the others; the player tells you when that happened (with PZFB 1.8.0 — on 1.7.x it can't tell).

## Platform Notes

**Tested on Linux** (Gentoo, Steam with pressure-vessel runtime). Everything works including ffmpeg detection inside Steam's container.

**Windows is untested** because zombies can get through them. If you're on Windows and try this mod, please report any issues — your feedback is greatly appreciated!

## Troubleshooting

**"ffmpeg not found"** — Install ffmpeg and make sure it's on your system PATH. Restart PZ after installing.

**No audio** — Audio takes a few seconds to prepare. If audio never appears, check that the video file actually has an audio track.

**Choppy playback** — Try a lower quality setting. Very Low (15%) works on nearly any system.

**Video not listed** — Make sure the file is in the correct `Zomboid/PZVP/` folder (not a subfolder) and has a supported extension (.mp4, .mkv, .avi, .webm, .mov, .flv).

**"Playback stopped: another mod took over PZFB's video slot"** — you started a PZEMU/PZDOOM game while a video was playing. Click **Open** and pick the video again.

**INSERT does nothing** — PZFB's class files aren't installed (PZFB shows a red "Setup Required" panel on the main menu until they are), or PZVP/PZFB aren't enabled for the save you loaded (Load Game → MORE... → Choose Mods...).

## Changes

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
