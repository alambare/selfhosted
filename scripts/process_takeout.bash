#!/bin/bash

root_folder="$1"

total_files=$(find "$root_folder" -type f | wc -l)
echo "$total_files discovered files."

#################### Rename invalid PNG to JPG ####################
echo "Stage 1: Renaming invalid PNG files to JPG..."

# Regular expression pattern for matching old and new filenames in the log
pattern="'(.*)'[[:space:]]-->[[:space:]]'(.*)'"

# Run exiftool to rename image files and capture output while also displaying it on the terminal
exiftool "$root_folder" -r '-filename<%f.$fileTypeExtension' -ext png -v | tee exiftool_rename.log |

# Parse the exiftool log file to extract old and new filenames
while IFS= read -r line; do
    # Look for lines with the format './old_filename' --> './new_filename'
    if [[ "$line" =~ $pattern ]]; then
        # Extract old and new filenames using regex capture groups
        old_file="${BASH_REMATCH[1]}"
        new_file="${BASH_REMATCH[2]}"

        # Construct the corresponding .json filenames
        json_old="${old_file}.json"
        json_new="${new_file}.json"

        # Check if the .json file exists and rename it
        if [ -f "$json_old" ]; then
            # Handle case where filenames only differ in case by renaming to a temporary file first
            mv -f "$json_old" "${json_old}.temp" && mv -f "${json_old}.temp" "$json_new"
            echo "Renamed $json_old to $json_new"
        else
            echo "No matching JSON file found for $json_old"
        fi
    fi
done

#################### Generate -edited metadata files ####################
echo "Stage 2: Generating '-edited' metadata files..."

# Process each edited image to create corresponding JSON files
find "$root_folder" -type f -name "*-edited.*" | while read -r edited_image; do
  # Remove the '-edited' part to get the base filename (without the extension)
  base_name="${edited_image%-edited.*}"
  
  # Find the corresponding JSON file based on the base name
  json_file="${base_name}.jpg.json"

  # Define the destination file name
  dest_file="${base_name}-edited.${edited_image##*.}.json"

  # Check if the corresponding JSON file exists
  if [ -f "$json_file" ]; then
    # Check if the destination file already exists
    if [ ! -f "$dest_file" ]; then
      # Create the edited JSON file by copying the original JSON file
      cp "$json_file" "$dest_file"
      echo "Copied $json_file to $dest_file"
    fi
  else
    echo "JSON file $json_file not found for $edited_image"
  fi
done

#################### Rename metadata files ending with .jpg(1).json to (1).jpg.json ####################
echo "Stage 3: Renaming metadata files ending with .jpg(1).json to (1).jpg.json..."

exiftool -ext json -r -if '$Filename=~/(\.[^.]+)(\(\d+\)).json$$/i'  '-Filename<${Filename;s/(\.[^.]+)(\(\d+\)).json$/$2$1.json/}' "$root_folder"


#################### Extensions to lower case + Resolve JSON sidecar files ####################
echo "Stage 4: Extensions to lower case + Resolve JSON sidecar files"

python3 ./resolve_json.py "$root_folder"

#################### Include Created Datetime if missing in videos (.mp4, .mov) ####################
echo "Stage 5: Adding missing elements in photos and videos"

exiftool -@ use_json.args "$root_folder"

#################### Script Completed ####################
echo "Script completed successfully."
