#!/bin/bash
# create_dmg.sh - Create a custom DMG with drag-to-install interface
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

echo "📦 Creating Notext installation DMG..."

# Find app
if [ -d "$DIST_DIR/Notext.app" ]; then
    APP_PATH="$DIST_DIR/Notext.app"
elif [ -f "$DIST_DIR/Notext.zip" ]; then
    cd "$DIST_DIR" && unzip -o Notext.zip -d /tmp/nx 2>/dev/null
    APP_PATH="/tmp/nx/Notext.app"
else
    echo "❌ Run 'make release' first." && exit 1
fi

[ ! -d "$APP_PATH" ] && echo "❌ App not found" && exit 1

VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "?")
echo "✓ Notext v$VER"

# Clean
rm -f "$DIST_DIR/Notext_Install.dmg" /tmp/nx_dmg* /tmp/nx_bg.png /tmp/nx_gen_bg /tmp/nx_gen_bg.m
rm -rf /tmp/nx_staging

# Create staging
mkdir -p /tmp/nx_staging/.background
cp -R "$APP_PATH" "/tmp/nx_staging/Notext.app"
ln -s /Applications "/tmp/nx_staging/Applications"

# ─── Create background image with CoreGraphics ───
echo "🎨 Creating background image..."

cat > /tmp/nx_gen_bg.m << 'OBJCEOF'
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <ImageIO/ImageIO.h>
#include <stdio.h>
static CGContextRef gc;
static CGColorSpaceRef gcs;
CGColorRef mkc(float r,float g,float b,float a){return CGColorCreate(gcs,(CGFloat[]){r,g,b,a});}
void dt(const char*t,float x,float y,float sz,float r,float g,float b,float al){
    CTFontRef f=CTFontCreateWithName(CFSTR("Helvetica Neue"),sz,NULL);
    CGColorRef c=mkc(r,g,b,al);
    const void*keys[]={kCTFontAttributeName,kCTForegroundColorAttributeName};
    const void*vals[]={f,c};
    CFDictionaryRef att=CFDictionaryCreate(NULL,keys,vals,2,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    CFStringRef s=CFStringCreateWithCString(NULL,t,kCFStringEncodingUTF8);
    CFAttributedStringRef as=CFAttributedStringCreate(NULL,s,att);
    CTLineRef l=CTLineCreateWithAttributedString(as);
    CGContextSetTextPosition(gc,x,y);CTLineDraw(l,gc);
    CFRelease(l);CFRelease(as);CFRelease(s);CFRelease(att);CFRelease(c);CFRelease(f);
}
int main(){
    int w=660,h=480;unsigned char*px=calloc(w*h*4,1);
    gcs=CGColorSpaceCreateDeviceRGB();
    gc=CGBitmapContextCreate(px,w,h,8,w*4,gcs,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGFloat locs[]={0,1},comps[]={0.10,0.10,0.18,1.0,0.06,0.06,0.12,1.0};
    CGGradientRef gr=CGGradientCreateWithColorComponents(gcs,comps,locs,2);
    CGContextDrawLinearGradient(gc,gr,CGPointMake(0,0),CGPointMake(w,h),0);CGGradientRelease(gr);
    CGContextSetRGBStrokeColor(gc,1,1,1,0.03);CGContextSetLineWidth(gc,0.5);
    for(int x=0;x<w;x+=20){CGContextMoveToPoint(gc,x,0);CGContextAddLineToPoint(gc,x,h);}
    for(int y=0;y<h;y+=20){CGContextMoveToPoint(gc,0,y);CGContextAddLineToPoint(gc,w,y);}
    CGContextStrokePath(gc);
    CGContextSetRGBFillColor(gc,0.05,0.05,0.05,0.8);CGContextFillRect(gc,CGRectMake(90,80,480,230));
    CGContextSetRGBStrokeColor(gc,0.42,0.39,1.0,0.6);CGContextSetLineWidth(gc,2);CGContextStrokeRect(gc,CGRectMake(90,80,480,230));
    dt("Notext",252,400,40,1,1,1,1);
    dt("Drag to Applications to install",175,368,15,1,1,1,0.5);
    dt("IMPORTANT",160,275,16,0.42,0.39,1.0,1);
    dt("This app is not signed by Apple, so macOS will block it.",115,248,12.5,1,1,1,0.7);
    dt("After copying to Applications, you need to allow it:",115,215,12.5,1,1,1,0.7);
    dt("  1. Open  System Settings",115,182,12.5,1,1,1,0.7);
    dt("  2. Go to  Privacy & Security",115,152,12.5,1,1,1,0.7);
    dt("  3. Scroll to Security section",115,122,12.5,1,1,1,0.7);
    dt("  4. Click  \"Open Anyway\"  next to Notext",115,92,12.5,1,1,1,0.7);
    CGImageRef img=CGBitmapContextCreateImage(gc);
    CFURLRef url=CFURLCreateWithFileSystemPath(NULL,CFSTR("/tmp/nx_bg.png"),kCFURLPOSIXPathStyle,false);
    CGImageDestinationRef d=CGImageDestinationCreateWithURL(url,CFSTR("public.png"),1,NULL);
    CGImageDestinationAddImage(d,img,NULL);CGImageDestinationFinalize(d);
    printf("OK %dx%d\n",w,h);
    CFRelease(d);CFRelease(url);CFRelease(img);CGContextRelease(gc);CGColorSpaceRelease(gcs);free(px);
    return 0;
}
OBJCEOF

clang -framework CoreGraphics -framework CoreText -framework ImageIO -framework CoreFoundation -o /tmp/nx_gen_bg /tmp/nx_gen_bg.m 2>/dev/null
/tmp/nx_gen_bg 2>/dev/null
cp /tmp/nx_bg.png /tmp/nx_staging/.background/bg.png

# ─── Create README file ───
cat > "/tmp/nx_staging/README.txt" << 'README'
===========================================
  Notext - Installation Instructions
===========================================

STEP 1: INSTALL
  Drag "Notext.app" to the "Applications" folder.

STEP 2: ALLOW IN SYSTEM SETTINGS
  Since Notext is not signed with an Apple
  Developer certificate, macOS will block
  it on first launch.

  To allow it:
  1. Open "System Settings"
  2. Go to "Privacy & Security"
  3. Scroll down to Security
  4. Click "Open Anyway" next to Notext
  5. Enter your password if prompted

STEP 3: ENJOY!
  Launch Notext from Applications.
  The first-run setup will guide you.

===========================================
README

# ─── Create writable DMG ───
echo "📀 Creating writable DMG..."
hdiutil create -srcfolder /tmp/nx_staging -volname "Notext Install" -fs HFS+ \
    -format UDRW -size 100m /tmp/nx_dmg_temp.dmg >/dev/null 2>&1

# Mount and get mount point
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen /tmp/nx_dmg_temp.dmg 2>/dev/null)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/Notext Install[^ ]*')

if [ -z "$MOUNT_POINT" ]; then
    echo "❌ Failed to mount DMG"
    exit 1
fi

echo "✓ Mounted at: $MOUNT_POINT"

# ─── Create .DS_Store using osascript ───
echo "💾 Creating .DS_Store with Finder settings..."

osascript -e "
tell application \"Finder\"
    tell disk \"Notext Install\"
        open
        delay 3
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {400, 180, 1060, 680}
        end tell
        delay 2
        tell icon view options of container window
            set icon size to 128
            set arrangement to not arranged
            set label position to bottom
            set shows icon preview to false
            set text size to 14
            set background picture to POSIX file \"$MOUNT_POINT/.background/bg.png\"
        end tell
        delay 2
        set position of item \"Notext.app\" to {160, 140}
        set position of item \"Applications\" to {500, 140}
        set position of item \"README.txt\" to {330, 350}
        delay 2
        close
    end tell
end tell
delay 3
" 2>&1 && echo "✓ Finder layout configured" || echo "⚠️ AppleScript had issues, trying fallback..."

# Force .DS_Store write
sync
sleep 2

# Check .DS_Store
DS_STORE="$MOUNT_POINT/.DS_Store"
if [ -f "$DS_STORE" ]; then
    SIZE=$(stat -f%z "$DS_STORE" 2>/dev/null || echo "0")
    echo "✓ .DS_Store exists ($SIZE bytes)"
else
    echo "⚠️ WARNING: .DS_Store not found!"
fi

# ─── Detach & compress ───
echo "📦 Compressing DMG..."
sleep 2
hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1
sleep 2

hdiutil convert /tmp/nx_dmg_temp.dmg -format UDZO -imagekey zlib-level=9 \
    -o "$DIST_DIR/Notext_Install.dmg" >/dev/null 2>&1

# Cleanup
rm -rf /tmp/nx_staging /tmp/nx_dmg* /tmp/nx /tmp/nx_bg.png /tmp/nx_gen_bg /tmp/nx_gen_bg.m 2>/dev/null

echo ""
echo "✅ DMG created: $DIST_DIR/Notext_Install.dmg ($(du -h "$DIST_DIR/Notext_Install.dmg" | cut -f1))"
echo ""
echo "📦 Contains:"
echo "   • Notext.app (the app)"
echo "   • Applications (symlink for drag)"
echo "   • README.txt (installation guide)"
echo "   • Custom background with security instructions"
