#!/bin/bash

root_folder="$1"

total_files=$(find "$root_folder" -type f | wc -l)
echo "$total_files discovered files."

#################### Rename invalid PNG to JPG ####################
echo "Stage 1: Renaming invalid PNG files to JPG..."

# Regular expression pattern for matching old and new filenames in the log
pattern="'(.*)'[[:space:]]-->[[:space:]]'(.*)'"

# Run exiftool to rename image files and capture output while also displaying it on the terminal
exiftool "$root_folder" -r '-filename<%f.$fileTypeExtension' -ext png -v | tee exiftool_log_rename.txt |

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

echo "Stage 1 completed: Renaming of invalid PNG files finished."

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

echo "Stage 2 completed: '-edited' metadata files generated."

#################### Rename metadata files ending with .jpg(1).json to (1).jpg.json ####################
echo "Stage 3: Renaming metadata files ending with .jpg(1).json to (1).jpg.json..."

find "$root_folder" -type f -name "*.jpg([0-9]).json" | while read -r file; do
    # Extract the directory and base name
    dir=$(dirname "$file")
    base=$(basename "$file")
    
    # Use sed to construct the new filename
    new_base=$(echo "$base" | sed -E 's/(.*)\.jpg\(([0-9])\)\.json/\1(\2).jpg.json/')
    
    # Rename the file
    mv "$file" "$dir/$new_base"
    echo "Renamed $file to $dir/$new_base"
done

echo "Stage 3 completed: Renaming metadata files finished."

#################### Include Created Datetime if missing in videos (.mp4, .mov) ####################
echo "Stage 4: Adding missing created datetime for videos..."

exiftool "$root_folder" -r -if '$CreateDate eq "0000:00:00 00:00:00"' -tagsfromfile %d%F.json -ext mp4 -ext mov '-Quicktime:CreateDate<JSON:PhotoTakenTimeTimestamp' -d %s

echo "Stage 4 completed: Missing datetime added to videos."

#################### Include Created Datetime if missing in photos ####################
echo "Stage 5: Adding missing created datetime for photos..."

exiftool "$root_folder" -r -if 'not $CreateDate' -tagsfromfile %d%F.json '-DateTimeOriginal<JSON:PhotoTakenTimeTimestamp' '-CreateDate<JSON:CreationTimeTimestamp' -d %s

echo "Stage 5 completed: Missing datetime added to photos."

#################### Script Completed ####################
echo "Script completed successfully."
