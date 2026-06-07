from PIL import Image

def remove_white_background(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()

    new_data = []
    # threshold for white
    for item in datas:
        # Assuming background is pure white or very close
        if item[0] > 245 and item[1] > 245 and item[2] > 245:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(output_path, "WEBP")

remove_white_background("image.webp", "image.webp")
