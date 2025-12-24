#!/usr/bin/env python3
import argparse
import os
import sys
from PIL import Image
import imagehash
from scenedetect import detect, ContentDetector, save_images, open_video

def main():
    parser = argparse.ArgumentParser(description="Detect scenes, save images, and deduplicate.")
    parser.add_argument("video_path", help="Path to the video file.")
    parser.add_argument("--output-dir", default="extracted_scenes", help="Directory to save images.")
    parser.add_argument("--threshold", type=int, default=5, help="Hamming distance threshold for deduplication (default: 5).")
    args = parser.parse_args()

    video_path = args.video_path
    output_dir = args.output_dir
    threshold = args.threshold

    if not os.path.exists(video_path):
        print(f"Error: Video file not found: {video_path}")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    print(f"Detecting scenes in {video_path}...")
    try:
        # Detect scenes using ContentDetector
        scenes = detect(video_path, ContentDetector())
        print(f"Detected {len(scenes)} scenes.")

        if not scenes:
            print("No scenes detected.")
            sys.exit(0)

        # Open video for frame extraction
        video = open_video(video_path)

        # Save 6 images per scene
        print("Saving 6 images per scene...")
        # save_images returns a dict {scene_idx: [image_paths]}
        image_filenames_dict = save_images(
            scenes,
            video,
            num_images=9,
            output_dir=output_dir,
            image_extension='png',
            show_progress=True
        )

        # Flatten the list of all generated images
        all_images = []
        for paths in image_filenames_dict.values():
            for p in paths:
                # Ensure we have the full path. scenedetect might return just filenames.
                if os.path.exists(p):
                    all_images.append(p)
                else:
                    full_path = os.path.join(output_dir, p)
                    if os.path.exists(full_path):
                        all_images.append(full_path)
                    else:
                        # If neither exists, append original (will likely fail later, but preserves logic)
                        all_images.append(p)
        
        print(f"Total images generated: {len(all_images)}")

        # Deduplication
        print("Deduplicating images using perceptual hashing...")
        kept_images = [] # List of (path, hash)
        duplicates_removed = 0

        # Sort images to process in order (Scene 1 img 1, Scene 1 img 2, etc.)
        all_images.sort()

        for img_path in all_images:
            try:
                with Image.open(img_path) as img:
                    # usage of phash (perceptual hash) is robust for "similar" looking images
                    curr_hash = imagehash.phash(img)
                
                is_duplicate = False
                for _, kept_hash in kept_images:
                    if curr_hash - kept_hash < threshold:
                        is_duplicate = True
                        break
                
                if is_duplicate:
                    # Remove the file
                    os.remove(img_path)
                    duplicates_removed += 1
                else:
                    kept_images.append((img_path, curr_hash))
            
            except Exception as e:
                print(f"Warning: Could not process image {img_path}: {e}")

        print(f"Deduplication complete.")
        print(f"Removed {duplicates_removed} duplicate images.")
        print(f"Remaining images: {len(kept_images)}")

    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
