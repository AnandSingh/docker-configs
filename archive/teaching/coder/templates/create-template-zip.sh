#!/bin/bash

# Create a Coder template zip file for web UI upload
# Run this script from the templates directory

set -e

TEMPLATE_DIR="fll-python"
OUTPUT_ZIP="fll-python-template.zip"

echo "Creating Coder template zip file..."

# Remove old zip if exists
rm -f "$OUTPUT_ZIP"

# Create zip file with template contents
cd "$TEMPLATE_DIR"
zip -r "../$OUTPUT_ZIP" . -x "*.pyc" -x "__pycache__/*" -x "*.swp" -x ".DS_Store"
cd ..

echo "✅ Template zip created: $OUTPUT_ZIP"
echo ""
echo "File size: $(du -h $OUTPUT_ZIP | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Download this file to your computer"
echo "2. Go to https://coder.lab.nexuswarrior.site"
echo "3. Click Templates → Create Template"
echo "4. Upload this zip file"
echo "5. Name: FLL Python"
echo "6. Click Create"
