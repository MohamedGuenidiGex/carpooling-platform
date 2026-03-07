#!/usr/bin/env python3
"""
Process the Gexpertise logo to make the G much larger relative to the background.
Aggressive cropping and scaling to maximize the G size.
"""

from PIL import Image
import os

def process_logo():
    # Paths
    input_path = r"c:\Users\LENOVO\OneDrive\Desktop\pfe\carpooling-platform\frontend\gexpertise_carpool\assets\images\logogexpertise.jpg"
    output_path = r"c:\Users\LENOVO\OneDrive\Desktop\pfe\carpooling-platform\frontend\gexpertise_carpool\assets\images\logogexpertise_cropped.jpg"
    
    # Open the image
    img = Image.open(input_path)
    
    # Convert to RGB if necessary
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Get image dimensions
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    # Find the bounding box of non-white content with a higher threshold
    # to catch more near-white pixels
    gray = img.convert('L')
    
    # More aggressive threshold - catch light gray/white space too
    threshold = 200
    
    # Find bounds
    left = width
    top = height
    right = 0
    bottom = 0
    
    for x in range(width):
        for y in range(height):
            if gray.getpixel((x, y)) < threshold:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
    
    print(f"Content bounds: ({left}, {top}) to ({right}, {bottom})")
    
    # No padding - crop tight to the content
    left = max(0, left)
    top = max(0, top)
    right = min(width, right)
    bottom = min(height, bottom)
    
    print(f"Tight crop: ({left}, {top}) to ({right}, {bottom})")
    
    # Crop the image
    cropped = img.crop((left, top, right, bottom))
    crop_width, crop_height = cropped.size
    print(f"Cropped size: {crop_width}x{crop_height}")
    
    # Create output size (1024x1024 for high quality icons)
    output_size = 1024
    square = Image.new('RGB', (output_size, output_size), (255, 255, 255))
    
    # Scale the cropped image to fill 85% of the output canvas (aggressive scaling)
    scale_factor = (output_size * 0.92) / max(crop_width, crop_height)
    new_width = int(crop_width * scale_factor)
    new_height = int(crop_height * scale_factor)
    
    scaled = cropped.resize((new_width, new_height), Image.LANCZOS)
    
    # Center the scaled image
    x_offset = (output_size - new_width) // 2
    y_offset = (output_size - new_height) // 2
    square.paste(scaled, (x_offset, y_offset))
    
    # Save the processed image
    square.save(output_path, 'JPEG', quality=95)
    print(f"Saved cropped logo to: {output_path}")
    print(f"Final size: {square.size}, G fills ~92% of canvas")
    
    return output_path

if __name__ == "__main__":
    process_logo()
