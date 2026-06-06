from PIL import Image
import os
import json

def process_image():
    img = Image.open('icon.png').convert('RGBA')
    data = img.getdata()
    
    black_geometry = []
    for item in data:
        if item[0] < 80 and item[1] < 80 and item[2] < 80 and item[3] > 0:
            black_geometry.append((0, 0, 0, item[3]))
        else:
            black_geometry.append((0, 0, 0, 0))
            
    img.putdata(black_geometry)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    size = 1024
    target_size = 800
    ratio = min(target_size / img.width, target_size / img.height)
    new_width = int(img.width * ratio)
    new_height = int(img.height * ratio)
    img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    x = (size - new_width) // 2
    y = (size - new_height) // 2
    
    # Light canvas
    light_canvas = Image.new('RGBA', (size, size), (255, 226, 0, 255))
    light_canvas.paste(img_resized, (x, y), img_resized)
    
    # Dark canvas
    white_geometry = []
    for item in img_resized.getdata():
        if item[3] > 0:
            white_geometry.append((255, 255, 255, item[3]))
        else:
            white_geometry.append((0, 0, 0, 0))
    white_img = Image.new('RGBA', img_resized.size)
    white_img.putdata(white_geometry)
    
    dark_canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    dark_canvas.paste(white_img, (x, y), white_img)
    
    appicon_dir = 'Assets.xcassets/AppIcon.appiconset'
    os.makedirs(appicon_dir, exist_ok=True)
    
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2)
    ]
    
    images_metadata = []
    
    for (s, scale) in sizes:
        pixel_size = s * scale
        
        # Light
        light_resized = light_canvas.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        light_name = f'light_{s}x{s}@{scale}x.png' if scale > 1 else f'light_{s}x{s}.png'
        light_resized.save(f'{appicon_dir}/{light_name}')
        images_metadata.append({
            "filename": light_name,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{s}x{s}"
        })
        
        # Dark
        dark_resized = dark_canvas.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        dark_name = f'dark_{s}x{s}@{scale}x.png' if scale > 1 else f'dark_{s}x{s}.png'
        dark_resized.save(f'{appicon_dir}/{dark_name}')
        images_metadata.append({
            "appearances": [{"appearance": "luminosity", "value": "dark"}],
            "filename": dark_name,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{s}x{s}"
        })

    contents = {
      "images": images_metadata,
      "info": { "author": "xcode", "version": 1 }
    }
    with open(f'{appicon_dir}/Contents.json', 'w') as f:
        json.dump(contents, f, indent=2)

if __name__ == '__main__':
    process_image()
