#!/usr/bin/env python3
"""Composes the iPhone Duo custom product page screenshots.

Usage: scripts/custom-page-screenshots.py <shots-dir> [output-dir]

<shots-dir> holds 1-game.png, 2-win.png and 3-lobby.png taken on the unfolded iPhone Duo
simulator (Device Hub pose: Open), launched the way app-store-screenshots.sh launches each
scene. Take them with the iOS Simulator tool's screenshot: `simctl io screenshot` returns a
black frame for the Duo's inner display. Each shot is set in a phone frame on brushed steel
with a caption, at 2778 x 1284, the landscape 6.5" iPhone slot (there is no Duo slot).
Needs Pillow (pip install pillow).
"""
import random
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

W, H = 2778, 1284
SF = '/System/Library/Fonts/SFNS.ttf'
ORANGE = (255, 149, 38)

def font(size, weight):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f

def background():
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(46 - 24 * t), int(40 - 21 * t), int(34 - 18 * t)))
    # Brushed-steel streaks, like the lobby.
    rnd = random.Random(7)
    streaks = Image.new('L', (W, H), 0)
    sd = ImageDraw.Draw(streaks)
    for y in range(0, H, 3):
        sd.line([(0, y), (W, y)], fill=rnd.randint(0, 14))
    img = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), img, streaks.point(lambda v: v // 2))
    # Torch glow behind the phone.
    glow = Image.new('RGB', (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse([1500, 150, 2600, 1150], fill=(120, 60, 10))
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    return ImageChops.add(img, glow)

def wrap(text, f, width, draw):
    lines, line = [], ''
    for word in text.split():
        test = (line + ' ' + word).strip()
        if draw.textlength(test, font=f) <= width:
            line = test
        else:
            lines.append(line); line = word
    lines.append(line)
    return lines

def device(shot_path, height):
    shot = Image.open(shot_path).convert('RGB')
    w = round(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    pad, r = 26, 70
    body = Image.new('RGBA', (w + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([0, 0, body.width - 1, body.height - 1], r + pad, fill=(12, 12, 14), outline=(92, 92, 98), width=4)
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, height - 1], r, fill=255)
    body.paste(shot, (pad, pad), mask)
    return body

def compose(shot_path, label, headline, sub, out):
    img = background()
    phone = device(shot_path, 1010)
    px = W - 110 - phone.width
    py = (H - phone.height) // 2
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([px + 10, py + 30, px + phone.width + 10, py + phone.height + 30], 96, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    img = img.convert('RGBA')
    img.alpha_composite(shadow)
    img.alpha_composite(phone, (px, py))
    d = ImageDraw.Draw(img)

    x, width = 130, px - 130 - 90
    lf, hf, sf = font(40, 'Bold'), font(104, 'Bold'), font(48, 'Regular')
    hl = wrap(headline, hf, width, d)
    sl = wrap(sub, sf, width, d)
    block = 40 + 46 + len(hl) * 120 + 40 + len(sl) * 66
    y = (H - block) // 2
    d.text((x, y), '  '.join(label.upper()), font=lf, fill=ORANGE)
    y += 40 + 36
    # Weld bead under the label.
    for bx in range(x, x + 300, 18):
        d.ellipse([bx, y - 10, bx + 16, y + 4], fill=(196, 190, 180), outline=(120, 115, 108))
    y += 40
    for line in hl:
        d.text((x, y), line, font=hf, fill=(246, 244, 240)); y += 120
    y += 40
    for line in sl:
        d.text((x, y), line, font=sf, fill=(190, 184, 176)); y += 66
    img.convert('RGB').save(out, quality=92)

if __name__ == '__main__':
    import os, sys
    shots, out = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'screenshots'
    os.makedirs(out, exist_ok=True)
    compose(f'{shots}/1-game.png', 'iPhone Duo',
            'Board on one side. Controls on the other.',
            'Open it up and the whole board fills the screen, with nothing sitting in the fold.',
            f'{out}/duo-1-game.jpg')
    compose(f'{shots}/2-win.png', 'Welding shop',
            'Earn your Certified Welder plate.',
            'Race four welding helmets home and send the other player back on a capture.',
            f'{out}/duo-2-win.jpg')
    compose(f'{shots}/3-lobby.png', 'Play your way',
            'A friend, the phone, or Torch.',
            'Two phones nearby with no internet, one phone passed around, or the computer welder.',
            f'{out}/duo-3-lobby.jpg')
