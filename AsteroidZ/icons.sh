#!/bin/bash

# Generate all required sizes directly into AppIcon.appiconset
for size in 16 32 128 256 512; do
    sips -z $size $size icon.png --out Assets.xcassets/AppIcon.appiconset/icon_${size}x${size}.png
    if [ $size != 512 ]; then
        sips -z $((size*2)) $((size*2)) icon.png --out Assets.xcassets/AppIcon.appiconset/icon_${size}x${size}@2x.png
    fi
done
sips -z 1024 1024 icon.png --out Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png

echo "Icon generation complete!"