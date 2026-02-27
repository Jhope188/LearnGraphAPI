#!/bin/bash
# Resize Harry Potter Character Photos for Entra ID
# Resizes images to 648x648 pixels using macOS sips

SOURCE_DIR="$HOME/Desktop/characters"
OUTPUT_DIR="$HOME/Desktop/characters-resized"

echo "Resizing character photos for Entra ID..."
echo "Source: $SOURCE_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Counter
success=0
total=0

# Process each image file
shopt -s nullglob
for img in "$SOURCE_DIR"/*.jpg "$SOURCE_DIR"/*.jpeg "$SOURCE_DIR"/*.png "$SOURCE_DIR"/*.JPG "$SOURCE_DIR"/*.JPEG "$SOURCE_DIR"/*.PNG; do
    
    total=$((total + 1))
    filename=$(basename "$img")
    basename="${filename%.*}"
    output_file="$OUTPUT_DIR/${basename}.png"
    
    echo "Processing: $filename"
    
    # Resize to 648x648 (will crop to square if needed)
    if sips -z 648 648 "$img" --out "$output_file" >/dev/null 2>&1; then
        filesize=$(ls -lh "$output_file" | awk '{print $5}')
        echo "  ✅ Resized to 648x648 - Size: $filesize"
        echo "  📁 Saved: ${basename}.png"
        echo ""
        success=$((success + 1))
    else
        echo "  ❌ Failed to resize"
        echo ""
    fi
done

# Summary
echo "═══════════════════════════════════════"
echo "Summary:"
echo "✅ Successfully resized: $success images"
echo "❌ Failed: $((total - success)) images"
echo "═══════════════════════════════════════"
echo ""
echo "Resized images saved to:"
echo "$OUTPUT_DIR"
echo ""
echo "These images are ready for Entra ID profile photos!"
