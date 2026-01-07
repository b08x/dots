#!/bin/bash

# Configuration
OLLAMA_HOST="http://192.168.41.28:11434"
PROMPT_DIR="$HOME/.prompts"
DATASET_DIR="$HOME/LLMOS/datasets"
TEMP_DIR="/tmp/ollama_capture"

# Ensure directories exist
mkdir -p "$PROMPT_DIR" "$DATASET_DIR" "$TEMP_DIR"

# -----------------------------------------------------------------------------
# 1. Image Processing (Optimal Conversion Architectures)
# -----------------------------------------------------------------------------

IMAGE_FILE="$1"

if [ -z "$IMAGE_FILE" ]; then
    echo "Usage: $0 <path_to_image>"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: File '$IMAGE_FILE' not found."
    exit 1
fi

echo "🔍 Optimizing image per Granite 3.2 Vision guidelines..."

# Check image dimensions using ImageMagick
IMG_WIDTH=$(identify -format "%w" "$IMAGE_FILE")
IMG_HEIGHT=$(identify -format "%h" "$IMAGE_FILE")
OPTIMIZED_IMAGE="${TEMP_DIR}/optimized_input.png"

# Optimization Logic:
# - Target: 1344px on the long edge (matches AnyRes 4x336 grid)
# - Format: PNG (Lossless, avoid JPEG artifacts)
# - Filter: Lanczos (Preserve text edges)
# - Colorspace: RGB (Preserve semantic color info)

if [ "$IMG_WIDTH" -gt 1344 ] || [ "$IMG_HEIGHT" -gt 1344 ]; then
    echo "   • Resizing to 1344px long-edge (Lanczos)"
    convert "$IMAGE_FILE" \
        -resize '1344x1344>' \
        -filter Lanczos \
        -colorspace sRGB \
        -quality 100 \
        "$OPTIMIZED_IMAGE"
else
    # If image is small (< 500px), user guide suggests Nearest Neighbor, 
    # but for safety we will just convert to standard PNG RGB if it's already small enough.
    echo "   • Converting to standardized PNG (sRGB)"
    convert "$IMAGE_FILE" -colorspace sRGB "$OPTIMIZED_IMAGE"
fi

# -----------------------------------------------------------------------------
# 2. Model Selection (Dynamic Ollama Query)
# -----------------------------------------------------------------------------

echo "🤖 Fetching models from $OLLAMA_HOST..."

# Get JSON, parse tags, and let user choose with gum
# We filter for likely vision models or show all. 
# For now, we show all as names can vary.
MODEL_LIST=$(curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[].name' | sort)

if [ -z "$MODEL_LIST" ]; then
    echo "Error: Could not retrieve models. Is Ollama running?"
    exit 1
fi

SELECTED_MODEL=$(echo "$MODEL_LIST" | gum choose --header "Select Vision Model")

if [ -z "$SELECTED_MODEL" ]; then
    echo "No model selected."
    exit 1
fi

# -----------------------------------------------------------------------------
# 3. Prompt Selection
# -----------------------------------------------------------------------------

# List files in ~/.prompts, strip extension for display
PROMPT_FILES=$(find "$PROMPT_DIR" -maxdepth 1 -name "*.txt" -exec basename {} .txt \;)

if [ -z "$PROMPT_FILES" ]; then
    echo "Error: No prompt files found in $PROMPT_DIR."
    echo "Please ensure you have text files (e.g., screenshot.txt) in this directory."
    exit 1
fi

SELECTED_PROMPT_NAME=$(echo "$PROMPT_FILES" | gum choose --header "Select Analysis Protocol")
PROMPT_CONTENT=$(cat "$PROMPT_DIR/${SELECTED_PROMPT_NAME}.txt")

# -----------------------------------------------------------------------------
# 4. Construct Payload & Optimize Parameters
# -----------------------------------------------------------------------------

# Encode optimized image to Base64
BASE64_DATA=$(base64 < "$OPTIMIZED_IMAGE" | tr -d '\n')

# Parameter Guidelines from "Optimal Conversion Architectures":
# - Temperature: 0.0 (Deterministic)
# - Repeat Penalty: 1.0 (Disabled for tables/code)
# - Num Ctx: 8192 (To fit ~6k vision tokens + output)

JSON_PAYLOAD=$(jq -n \
                  --arg model "$SELECTED_MODEL" \
                  --arg prompt "$PROMPT_CONTENT" \
                  --arg img "$BASE64_DATA" \
                  '{
    model: $model,
    messages: [
      {
        role: "user",
        content: $prompt,
        images: [$img]
      }
    ],
    stream: false,
    options: {
      temperature: 0.0,
      repeat_penalty: 1.0,
      num_ctx: 8192
    }
  }')

echo "🚀 Sending request to $SELECTED_MODEL (Ctx: 8192, Temp: 0.0)..."

# -----------------------------------------------------------------------------
# 5. Execute Request
# -----------------------------------------------------------------------------

RESPONSE_JSON=$(curl -s -X POST "${OLLAMA_HOST}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

# Extract content or error
CONTENT=$(echo "$RESPONSE_JSON" | jq -r '.message.content // empty')
ERROR=$(echo "$RESPONSE_JSON" | jq -r '.error // empty')

if [ -n "$ERROR" ]; then
    echo "❌ API Error: $ERROR"
    exit 1
fi

if [ -z "$CONTENT" ] || [ "$CONTENT" == "null" ]; then
    echo "❌ Empty response received."
    exit 1
fi

# -----------------------------------------------------------------------------
# 6. Display & Log Results
# -----------------------------------------------------------------------------

# Render Markdown to terminal
echo ""
echo "$CONTENT" | gum format
echo ""

# Logging to Dataset CSV
# Clean model name for filename (replace : with -)
SAFE_MODEL_NAME=$(echo "$SELECTED_MODEL" | tr ':' '-')
CSV_FILE="${DATASET_DIR}/${SAFE_MODEL_NAME}.csv"

# Check if CSV exists, if not create header
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,image_source,prompt_name,model,parameters,response_text" > "$CSV_FILE"
fi

# Escape content for CSV (replace quotes with double quotes, wrap in quotes)
# We use jq to safely serialize the string for CSV inclusion
CSV_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CSV_PARAMS='{"temperature":0.0,"num_ctx":8192,"repeat_penalty":1.0}'

# Use jq to format the CSV line to handle newlines/quotes in the response text correctly
jq -n \
    --arg ts "$CSV_TIMESTAMP" \
    --arg img "$IMAGE_FILE" \
    --arg p_name "$SELECTED_PROMPT_NAME" \
    --arg mod "$SELECTED_MODEL" \
    --arg params "$CSV_PARAMS" \
    --arg resp "$CONTENT" \
    '[$ts, $img, $p_name, $mod, $params, $resp] | @csv' \
    | tr -d '\\' | sed 's/^"//;s/"$//' >> "$CSV_FILE" 
    # Note: simple CSV appending is tricky with shell, jq @csv is safest but produces quotes we might need to adjust depending on preference.
    # The above jq command outputs a valid CSV row "val1","val2"...

echo "💾 Saved analysis to $CSV_FILE"

# Cleanup
rm "$OPTIMIZED_IMAGE"