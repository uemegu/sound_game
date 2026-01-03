#!/bin/bash

# This script generates music charts from an MP3 file and integrates them into the game.
#
# Usage:
# ./run.sh <path_to_mp3_file>
#
# Example:
# ./run.sh "data/Yoru ni Omou.mp3"
#
# The script expects a corresponding .jpeg file with the same basename in the same directory as the .mp3 file.
# For example, if you provide "data/Yoru ni Omou.mp3", it will look for "data/Yoru ni Omou.jpeg".

set -e

# --- Configuration ---
# Path to the python executable in the virtual environment
PYTHON_EXEC="create_data/venv/bin/python"
# Path to the chart generation script
CREATE_SCRIPT="create_data/create.py"
# Path to the tracks.json update script
UPDATE_SCRIPT="create_data/update_tracks.py"
# Directory where the game's data is stored
DOCS_DATA_DIR="docs/data"
# Temporary directory for generated charts and padded audio
TEMP_OUTPUT_DIR="temp_charts"
PADDED_MP3_FILE="$TEMP_OUTPUT_DIR/padded.mp3"

# --- Script ---

# 1. Check for input file
MP3_FILE="$1"
if [ -z "$MP3_FILE" ]; then
    echo "Usage: $0 <path_to_mp3_file>"
    exit 1
fi

if [ ! -f "$MP3_FILE" ]; then
    echo "Error: File not found at '$MP3_FILE'"
    exit 1
fi

# 2. Extract song title and basename
SONG_BASENAME=$(basename "$MP3_FILE" .mp3)
SONG_TITLE=$SONG_BASENAME # For now, title is the same as the basename. Can be changed later.
SOURCE_DIR=$(dirname "$MP3_FILE")
JPEG_FILE="$SOURCE_DIR/$SONG_BASENAME.jpeg"

if [ ! -f "$JPEG_FILE" ]; then
    echo "Warning: JPEG file not found at '$JPEG_FILE'. The 'cover' field in tracks.json might be incorrect."
fi


# 3. Create temporary output directory and padded audio file
rm -rf "$TEMP_OUTPUT_DIR"
mkdir -p "$TEMP_OUTPUT_DIR"
echo "Created temporary directory: $TEMP_OUTPUT_DIR"

echo "Adding 2 seconds of silence to the beginning of the audio..."
ffmpeg -y -i "$MP3_FILE" \
  -af "adelay=2000|2000" \
  -ar 44100 -ac 2 \
  "$PADDED_MP3_FILE"
echo "Padded audio created at $PADDED_MP3_FILE"


# 4. Run the chart generation script
echo "Generating charts for '$PADDED_MP3_FILE'..."
"$PYTHON_EXEC" -c "
import sys
sys.path.append('create_data')
from create import batch_generate_charts
batch_generate_charts(mp3_path='$PADDED_MP3_FILE', output_dir='$TEMP_OUTPUT_DIR', title='$SONG_BASENAME')
"
echo "Chart generation complete."

# 5. Copy generated files to docs/data
echo "Copying files to $DOCS_DATA_DIR..."

# Copy audio and cover (padded audio and original cover)
if [ "$PADDED_MP3_FILE" != "$DOCS_DATA_DIR/$SONG_BASENAME.mp3" ]; then
    cp -f "$PADDED_MP3_FILE" "$DOCS_DATA_DIR/$SONG_BASENAME.mp3"
fi
if [ -f "$JPEG_FILE" ] && [ "$JPEG_FILE" != "$DOCS_DATA_DIR/$SONG_BASENAME.jpeg" ]; then
    cp -f "$JPEG_FILE" "$DOCS_DATA_DIR/$SONG_BASENAME.jpeg"
fi

# Copy only normal and hard charts
for diff in normal hard; do
    CHART_FILE="$TEMP_OUTPUT_DIR/${SONG_BASENAME}_${diff}.json"
    DEST_FILE="$DOCS_DATA_DIR/${SONG_BASENAME}_${diff}.json"
    if [ -f "$CHART_FILE" ]; then
        if [ "$CHART_FILE" != "$DEST_FILE" ]; then
            cp -f "$CHART_FILE" "$DEST_FILE"
        fi
        echo "Copied $CHART_FILE"
    else
        echo "Warning: ${diff} chart not found for $SONG_BASENAME"
    fi
done

# 6. Update tracks.json
echo "Updating $DOCS_DATA_DIR/tracks.json..."
"$PYTHON_EXEC" "$UPDATE_SCRIPT" "$DOCS_DATA_DIR/tracks.json" "$SONG_TITLE" "$SONG_BASENAME"
echo "tracks.json updated."

# 7. Clean up temporary directory
rm -rf "$TEMP_OUTPUT_DIR"
echo "Cleaned up temporary directory."

echo "Successfully added '$SONG_TITLE' to the game."
