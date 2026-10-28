"""Create a temporary, original ADNANLOAD-branded icon without external fonts.
Not the historical R14.8 icon (source artwork not present in supplied archive).
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

root=Path(__file__).resolve().parents[1]
img=Image.new('RGBA',(512,512),(0,0,0,0))
d=ImageDraw.Draw(img)
d.rounded_rectangle((9,9,503,503),radius=110,fill=(9,13,19,255),outline=(179,133,45),width=7)
d.ellipse((88,86,424,422),fill=(27,32,39,255),outline=(234,190,93,255),width=18)
d.line([(256,155),(256,321)],fill=(248,210,121,255),width=46,joint='curve')
d.polygon([(169,264),(256,364),(343,264),(313,238),(256,304),(199,238)],fill=(255,222,139,255))
# Signature four-point crown at the upper arc.
d.polygon([(199,114),(223,69),(256,98),(289,69),(313,114),(313,143),(199,143)],fill=(248,200,88,255))
d.ellipse((216,60,230,74),fill=(255,238,177,255))
d.ellipse((282,60,296,74),fill=(255,238,177,255))
d.ellipse((249,90,263,104),fill=(255,238,177,255))
assets=root/'assets';assets.mkdir(exist_ok=True)
img.save(assets/'adnanload_mark.png')
android=root/'android/app/src/main/res'
sizes={'mipmap-mdpi':48,'mipmap-hdpi':72,'mipmap-xhdpi':96,'mipmap-xxhdpi':144,'mipmap-xxxhdpi':192}
if android.exists():
    for folder,size in sizes.items():
        dest=android/folder;dest.mkdir(parents=True,exist_ok=True)
        img.resize((size,size),Image.Resampling.LANCZOS).save(dest/'ic_launcher.png')
    print('Android app icons generated in res/mipmap-*')
print('Asset icon generated:',assets/'adnanload_mark.png')
