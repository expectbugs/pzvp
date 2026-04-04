#!/bin/bash
# PZVP — Manual Video Converter
# Converts a video file to raw RGBA frames + OGG audio for PZVP.
# The in-game mod does this automatically, but this script can be used
# for pre-conversion or debugging.
#
# Usage: ./convert.sh <input_video> [name] [width] [height]
# Output goes to ~/Zomboid/PZVP/converted/<name>/

set -e

INPUT="$1"
NAME="${2:-$(basename "${INPUT%.*}")}"
W="${3:-256}"
H="${4:-192}"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <input_video> [name] [width] [height]"
    echo "  Default resolution: 256x192"
    echo "  Output: ~/Zomboid/PZVP/converted/<name>/"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file not found: $INPUT"
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "ERROR: ffmpeg not found. Install ffmpeg first."
    exit 1
fi

OUTDIR="$HOME/Zomboid/PZVP/converted/$NAME"
mkdir -p "$OUTDIR"

echo "Converting: $INPUT"
echo "Output:     $OUTDIR"
echo "Resolution: ${W}x${H}"
echo ""

# Convert video to raw RGBA frames
echo "Converting video..."
ffmpeg -y -i "$INPUT" -vf "scale=${W}:${H}" -pix_fmt rgba -f rawvideo "$OUTDIR/video.raw"

# Extract audio
echo "Extracting audio..."
ffmpeg -y -i "$INPUT" -vn -acodec libvorbis -q:a 5 "$OUTDIR/audio.ogg" 2>/dev/null || true

# Get FPS
FPS_RAW=$(ffprobe -v 0 -select_streams v -of csv=p=0 -show_entries stream=r_frame_rate "$INPUT" | head -1)
# Convert fraction to decimal if needed
FPS=$(python3 -c "
f = '$FPS_RAW'.strip().split(',')[0]
if '/' in f:
    n, d = f.split('/')
    print(float(n)/float(d))
else:
    print(f)
" 2>/dev/null || echo "$FPS_RAW")

# Calculate frame count
RAWSIZE=$(stat -c%s "$OUTDIR/video.raw")
FRAMESIZE=$((W * H * 4))
FRAMES=$((RAWSIZE / FRAMESIZE))

# Check for audio
AUDIO_PATH=""
if [ -f "$OUTDIR/audio.ogg" ] && [ -s "$OUTDIR/audio.ogg" ]; then
    AUDIO_PATH="$OUTDIR/audio.ogg"
fi

# Write metadata
cat > "$OUTDIR/meta.txt" <<METAEOF
width=$W
height=$H
frames=$FRAMES
fps=$FPS
audio=$AUDIO_PATH
raw=$OUTDIR/video.raw
METAEOF

echo ""
echo "Done! $FRAMES frames @ ${FPS} fps"
echo "Raw size: $(du -h "$OUTDIR/video.raw" | cut -f1)"
if [ -n "$AUDIO_PATH" ]; then
    echo "Audio: $AUDIO_PATH"
else
    echo "Audio: none (video has no audio track)"
fi
echo ""
echo "In-game: Press F7 to open the video player."
