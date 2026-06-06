from PIL import Image, ImageDraw, ImageOps, ImageFilter
import os
import json
import subprocess

def create_mac_squircle_mask(size, padding):
    # macOS standard icon size is 824x824 inside a 1024x1024 canvas
    inner_size = size - (padding * 2)
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    # Corner radius is 22.5% of the inner squircle size
    r = int(inner_size * 0.225)
    draw.rounded_rectangle((padding, padding, size-padding, size-padding), radius=r, fill=255)
    return mask

def add_drop_shadow(image, alpha_mask, offset=(0, 20), blur_radius=15, opacity=120):
    shadow = Image.new('RGBA', image.size, (0, 0, 0, 0))
    shadow_mask = Image.new('L', image.size, 0)
    shadow_mask.paste(alpha_mask, offset)
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    shadow_mask = shadow_mask.point(lambda p: int(p * (opacity / 255.0)))
    
    shadow.putalpha(shadow_mask)
    return Image.alpha_composite(shadow, image)

def create_gradient_bg(size, padding, color_top, color_bottom):
    base = Image.new('RGBA', (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(base)
    r1, g1, b1 = color_top
    r2, g2, b2 = color_bottom
    
    inner_size = size - (padding * 2)
    
    for y in range(inner_size):
        r = int(r1 + (r2 - r1) * y / inner_size)
        g = int(g1 + (g2 - g1) * y / inner_size)
        b = int(b1 + (b2 - b1) * y / inner_size)
        draw.line([(padding, padding + y), (size - padding, padding + y)], fill=(r, g, b, 255))
    return base

def add_3d_inner_glow(image, size, padding):
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    inner_size = size - (padding * 2)
    r = int(inner_size * 0.225)
    
    # Top highlight
    draw.rounded_rectangle((padding+3, padding+3, size-padding-3, size-padding-3), radius=r-3, outline=(255, 255, 255, 180), width=6)
    # Bottom shadow
    draw.rounded_rectangle((padding+3, padding+10, size-padding-3, size-padding-1), radius=r-3, outline=(0, 0, 0, 80), width=6)
    
    glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
    return Image.alpha_composite(image, glow)

def process_image():
    original = Image.open('icon.png').convert('L')
    
    mask = original.point(lambda p: 255 if p > 160 else 0)
    mask = ImageOps.invert(mask)
    bbox = mask.getbbox()
    if bbox:
        mask = mask.crop(bbox)
        
    big_mask = mask.resize((mask.width * 4, mask.height * 4), Image.Resampling.NEAREST)
    big_mask = big_mask.filter(ImageFilter.GaussianBlur(radius=6))
    big_mask = big_mask.point(lambda p: 255 if p > 128 else 0)
    final_mask = big_mask.resize((mask.width, mask.height), Image.Resampling.LANCZOS)
        
    size = 1024
    padding = 100
    target_logo_size = 480
    
    ratio = min(target_logo_size / final_mask.width, target_logo_size / final_mask.height)
    new_width = int(final_mask.width * ratio)
    new_height = int(final_mask.height * ratio)
    
    alpha_resized = final_mask.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    full_logo_mask = Image.new('L', (size, size), 0)
    x = (size - new_width) // 2
    y = (size - new_height) // 2
    full_logo_mask.paste(alpha_resized, (x, y))

    squircle_mask = create_mac_squircle_mask(size, padding)

    # --- LIGHT MODE: Yellow Gradient Squircle, Black logo ---
    light_bg = create_gradient_bg(size, padding, (255, 235, 20), (240, 180, 0))
    light_bg = add_3d_inner_glow(light_bg, size, padding)
    light_bg.putalpha(squircle_mask)
    
    # Add external drop shadow to the squircle itself for true macOS standard
    light_canvas_with_shadow = Image.new('RGBA', (size, size), (0,0,0,0))
    light_canvas_with_shadow = add_drop_shadow(light_bg, squircle_mask, offset=(0, 20), blur_radius=30, opacity=80)
    
    black_logo = Image.new('RGBA', (size, size), (20, 20, 20, 255))
    black_logo.putalpha(full_logo_mask)
    
    light_content = add_drop_shadow(black_logo, full_logo_mask, offset=(0, 15), blur_radius=15, opacity=70)
    light_final = Image.alpha_composite(light_canvas_with_shadow, light_content)
    
    # --- DARK MODE: Dark Charcoal Squircle, Yellow logo ---
    dark_bg = create_gradient_bg(size, padding, (60, 60, 65), (28, 28, 30))
    dark_bg = add_3d_inner_glow(dark_bg, size, padding)
    dark_bg.putalpha(squircle_mask)
    
    dark_canvas_with_shadow = Image.new('RGBA', (size, size), (0,0,0,0))
    dark_canvas_with_shadow = add_drop_shadow(dark_bg, squircle_mask, offset=(0, 20), blur_radius=30, opacity=120)
    
    yellow_logo = Image.new('RGBA', (size, size), (255, 226, 0, 255))
    yellow_logo.putalpha(full_logo_mask)
    
    dark_content = add_drop_shadow(yellow_logo, full_logo_mask, offset=(0, 15), blur_radius=15, opacity=180)
    dark_final = Image.alpha_composite(dark_canvas_with_shadow, dark_content)

    # Save to Asset Catalog
    appicon_dir = 'Assets.xcassets/AppIcon.appiconset'
    os.makedirs(appicon_dir, exist_ok=True)
    
    sizes = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
    images_metadata = []
    
    for (s, scale) in sizes:
        pixel_size = s * scale
        
        # Light
        light_resized = light_final.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        light_name = f'light_{s}x{s}@{scale}x.png' if scale > 1 else f'light_{s}x{s}.png'
        light_resized.save(f'{appicon_dir}/{light_name}')
        images_metadata.append({
            "filename": light_name,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{s}x{s}"
        })
        
        # Dark
        dark_resized = dark_final.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
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
        
    # Also generate a fallback .icns of the Light Mode one
    os.makedirs('AppIcon.iconset', exist_ok=True)
    light_final.save('AppIcon.iconset/icon_512x512@2x.png')
    for s in [16, 32, 64, 128, 256, 512]:
        subprocess.run(['sips', '-z', str(s), str(s), 'AppIcon.iconset/icon_512x512@2x.png', '--out', f'AppIcon.iconset/icon_{s}x{s}.png'], check=True)
        subprocess.run(['sips', '-z', str(s*2), str(s*2), 'AppIcon.iconset/icon_512x512@2x.png', '--out', f'AppIcon.iconset/icon_{s}x{s}@2x.png'], check=True)
    subprocess.run(['iconutil', '-c', 'icns', 'AppIcon.iconset', '-o', 'AppIcon.icns'], check=True)

if __name__ == '__main__':
    process_image()
