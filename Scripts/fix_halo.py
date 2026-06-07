from PIL import Image

def eat_halo(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    
    # Do 4 passes of eroding bright pixels that touch transparent pixels
    for _ in range(4):
        pixels = img.load()
        to_remove = []
        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                if a == 0: continue
                
                # Check neighbors
                touches_transparent = False
                for dx, dy in [(-1,0), (1,0), (0,-1), (0,1), (-1,-1), (1,-1), (-1,1), (1,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < width and 0 <= ny < height:
                        if pixels[nx, ny][3] < 10:
                            touches_transparent = True
                            break
                    else:
                        touches_transparent = True
                
                if touches_transparent:
                    brightness = (r + g + b) / 3.0
                    if brightness > 60: # halo pixels are gray/white
                        to_remove.append((x, y))
        
        for x, y in to_remove:
            pixels[x, y] = (0, 0, 0, 0)
            
    # One final pass to feather the absolute edge
    pixels = img.load()
    to_fade = []
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0: continue
            touches_transparent = False
            for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                nx, ny = x+dx, y+dy
                if 0 <= nx < width and 0 <= ny < height:
                    if pixels[nx, ny][3] < 10:
                        touches_transparent = True
                        break
            if touches_transparent:
                to_fade.append((x, y, r, g, b))
                
    for x, y, r, g, b in to_fade:
        pixels[x, y] = (r, g, b, 100)
            
    img.save(output_path, "WEBP")

eat_halo("image.webp", "image.webp")
