#!/bin/bash
# Terminal app UI end-to-end tests: drives the real app through adb and reads the screen with OCR (tesseract).
# Needs: adb, a USB-debugging phone with the app set up, tesseract, python3 + Pillow. The phone screen must be on/unlocked.
ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"; ADB="$ANDROID_HOME/platform-tools/adb"
PKG=app.clipod; ACT=$PKG/com.termux.app.TermuxActivity; W=${TMPDIR:-/tmp}/terminal-ui-test; mkdir -p "$W"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s  %s\n' "$1" "$2"; }
shot() { "$ADB" shell screencap -p /sdcard/ui.png && "$ADB" pull -q /sdcard/ui.png "$W/$1.png" && "$ADB" shell rm /sdcard/ui.png
  python3 - "$W/$1.png" <<'PY'
import sys
from PIL import Image, ImageOps
im=Image.open(sys.argv[1]).convert('L'); im=ImageOps.invert(im).point(lambda p:255 if p>110 else 0); im.save(sys.argv[1].replace('.png','-ocr.png'))
PY
  tesseract "$W/$1-ocr.png" - --psm 6 2>/dev/null | tr -d '\r'; }
typ()  { "$ADB" shell "input text '$(echo "$1" | sed 's/ /%s/g')'"; "$ADB" shell input keyevent 66; }
fg()   { "$ADB" shell dumpsys activity activities | grep -m1 topResumedActivity | grep -q $PKG; }
launch() { "$ADB" shell am force-stop $PKG; "$ADB" shell am start -n $ACT >/dev/null 2>&1; for i in $(seq 1 20); do sleep 1; fg && break; done; sleep "${1:-6}"; }
tap_xml() { # tap the node whose text/desc contains $1
  "$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; "$ADB" pull -q /sdcard/ui.xml "$W/ui.xml" 2>/dev/null
  python3 - "$W/ui.xml" "$1" <<'PY'
import sys,re,xml.etree.ElementTree as ET,subprocess
t=ET.parse(sys.argv[1]); want=sys.argv[2].lower()
for n in t.iter('node'):
    if want in (n.get('text','')+' '+n.get('content-desc','')).lower():
        m=re.findall(r'\d+',n.get('bounds')); x=(int(m[0])+int(m[2]))//2; y=(int(m[1])+int(m[3]))//2
        print(x,y); sys.exit(0)
sys.exit(1)
PY
}
echo "== UI end-to-end"
"$ADB" get-state >/dev/null 2>&1 || { echo "no device"; exit 1; }
"$ADB" shell input keyevent KEYCODE_WAKEUP; "$ADB" shell wm dismiss-keyguard 2>/dev/null

launch 7
fg && ok "app opens and stays in foreground" || bad "app opens" "not foreground"
OUT=$(shot s1); typ "echo UITEST4721"; sleep 2; OUT=$(shot s1b)
[ "$(echo "$OUT" | grep -c UITEST4721)" -ge 2 ] && ok "prompt accepts typing and runs commands" || bad "typing/run" "$(echo "$OUT" | tail -3)"
BL=$(python3 -c "
from PIL import Image; im=Image.open('$W/s1b.png').convert('L'); px=list(im.getdata()); print(sum(1 for p in px if p>80)*100//len(px))")
[ "$BL" -ge 1 ] && ok "screen is not blank (${BL}% lit)" || bad "screen blank" "$BL%"

# keyboard opens on tap
"$ADB" shell input keyevent 4; sleep 1; "$ADB" shell input tap 540 700; sleep 2
"$ADB" shell dumpsys input_method | grep -q 'mInputShown=true' && ok "tapping the screen opens the keyboard" || bad "keyboard on tap" "mInputShown=false"

# session independence
typ "export SESSVAR=ONE"; sleep 1
"$ADB" shell input swipe 3 1200 700 1200 150; sleep 1.5
XY=$(tap_xml "new session") && { "$ADB" shell input tap $XY; sleep 3; ok "drawer opens and 'New session' works"; } || bad "new session button" "not found in drawer"
typ "echo X\${SESSVAR}Y"; sleep 2; OUT=$(shot s2)
echo "$OUT" | grep -qE 'XY' && ! echo "$OUT" | grep -q 'XONEY' && ok "new session is independent (variable not shared)" || bad "session independence" "$(echo "$OUT"|tail -3)"
"$ADB" shell input swipe 3 1200 700 1200 150; sleep 1.5
XY=$(tap_xml "TermuxSession") || XY=""
if [ -z "$XY" ]; then "$ADB" shell input swipe 3 1200 700 1200 150; sleep 1; fi
# go back to session 1 via the first entry in the session list
"$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; "$ADB" pull -q /sdcard/ui.xml "$W/ui.xml" 2>/dev/null
Y1=$(python3 - "$W/ui.xml" <<'PY'
import sys,re,xml.etree.ElementTree as ET
t=ET.parse(sys.argv[1])
for n in t.iter('node'):
    if re.search(r'^\s*\[?1\]?\b|1:|session',(n.get('text','')+n.get('content-desc','')).lower()) and n.get('clickable')=='true':
        m=re.findall(r'\d+',n.get('bounds')); print((int(m[0])+int(m[2]))//2,(int(m[1])+int(m[3]))//2); break
PY
)
[ -n "$Y1" ] && "$ADB" shell input tap $Y1 && sleep 2 && typ "echo X\${SESSVAR}Y" && sleep 2 && OUT=$(shot s3) && echo "$OUT" | grep -q 'XONEY' && ok "switching back to session 1 shows its own state" || bad "switch back" "could not select session 1 / value missing"

# the user's reported bug: claude TUI, then close/reopen
"$ADB" shell input keyevent 4; typ "claude"; sleep 14; OUT=$(shot c1)
echo "$OUT" | grep -qiE 'claude|welcome|trust|sign in|login|select|theme|tips' && ok "claude interactive UI starts" || bad "claude TUI" "$(echo "$OUT"|head -5)"
"$ADB" shell input keycombination 113 31; sleep 1; "$ADB" shell input keycombination 113 31; sleep 2
typ "echo AFTERCLAUDE88"; sleep 2; OUT=$(shot c2)
[ "$(echo "$OUT" | grep -c AFTERCLAUDE88)" -ge 1 ] && ok "terminal still responds after leaving claude" || bad "after claude" "$(echo "$OUT"|tail -3)"
for i in 1 2 3; do
  launch 6; typ "echo REOPEN${i}OK"; sleep 2; OUT=$(shot r$i)
  echo "$OUT" | grep -q "REOPEN${i}OK" && ok "reopen #$i: terminal responds (no blank/frozen screen)" || bad "reopen #$i" "$(echo "$OUT"|tail -3)"
done
echo; echo "UI RESULT: $PASS passed, $FAIL failed   (screenshots in $W)"; [ $FAIL -eq 0 ]
