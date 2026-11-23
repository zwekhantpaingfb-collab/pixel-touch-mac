#!/bin/bash
# Pixel Touch - Copyright (c) 2026 ThihaSoe (Thanbyuzayat, Myanmar). All rights reserved.
#
# Terminal installer for the Mac - no developer account, no "Open Anyway":
# a file curl downloads carries no quarantine, so macOS lets it run.
#
#   curl -fsSL https://pixel-touch-license.web.app/mac | bash
#   curl -fsSL https://pixel-touch-license.web.app/mac | bash -s uninstall
#
# The big payload (engine, its Python, the models - about 1.1 GB) comes
# from the GitHub release zwekhantpaingfb-collab/pixel-touch-mac (the latest one), with resume: a broken
# download picks up where it stopped when the line is run again. The work
# itself is done by the same install.sh "Install Pixel Touch.app" uses
# (published beside it as pixeltouch-steps.sh), one step at a time.
# make_mac_web.sh fills in zwekhantpaingfb-collab/pixel-touch-mac.
set -e
REPO="zwekhantpaingfb-collab/pixel-touch-mac"
BASE="${PT_WEB_BASE:-https://github.com/$REPO/releases/latest/download}"
WORK="$HOME/Library/Caches/PixelTouch-Install"
MODE="${1:-install}"

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31m✘ %s\033[0m\n' "$*" >&2
         say "ထည့်သွင်းလို့ မရရင် ဒီ Terminal ကို screenshot ရိုက်ပြီး ဆက်သွယ်ပါ။"; exit 1; }
ask()  { # waits for Enter on the keyboard (stdin is this script under "| bash")
         if [ -r /dev/tty ]; then read -r _ </dev/tty || true; else sleep 5; fi; }

say ""
say "════════════════════════════════════════"
say "  Pixel Touch — Mac Installer"
say "════════════════════════════════════════"

[ "$(uname -m)" = "arm64" ] || die "ဒီ Mac က Intel ပါ။ Pixel Touch က Apple Silicon (M1, M2, M3, M4 ...) Mac မှာပဲ သုံးလို့ရပါတယ်။"
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "${MAJOR:-0}" -ge 14 ] || die "macOS $(sw_vers -productVersion) ပါ။ macOS 14 (Sonoma) နဲ့ အထက် လိုပါတယ်။"

close_photoshop() {
  [ -n "$PT_NO_LAUNCHD" ] && return 0   # test hook, as install.sh's
  while pgrep -qf "Adobe Photoshop 20[0-9][0-9].app/Contents/MacOS"; do
    say ""
    say "⚠️  Photoshop ပွင့်နေပါတယ်။ Photoshop ကို ပိတ်ပြီး (⌘ + Q) ဒီမှာ Enter နှိပ်ပါ။"
    say "    Please quit Photoshop, then press Enter."
    ask
  done
}

mkdir -p "$WORK"
cd "$WORK"

fetch_small() {  # name -> file in WORK, overwritten
  curl -fsSL --retry 5 --retry-delay 3 -o "$1" "$BASE/$1" \
    || die "\"$1\" ကို ဒေါင်းလို့ မရပါ။ အင်တာနက် ချိတ်ထားလား စစ်ပြီး ပြန်ရိုက်ပါ။"
}

step "သတင်းအချက်အလက် ယူနေပါတယ်…"
fetch_small VERSION
fetch_small SHA256SUMS
fetch_small pixeltouch-steps.sh
VER="$(tr -d '[:space:]' < VERSION)"
cp pixeltouch-steps.sh install.sh
chmod +x install.sh
ok "Pixel Touch $VER"

if [ "$MODE" = "uninstall" ]; then
  close_photoshop
  step "Pixel Touch ကို ဖယ်ရှားနေပါတယ်…"
  /bin/bash ./install.sh uninstall || die "ဖယ်ရှားလို့ မရပါ"
  rm -rf "$WORK"
  ok "Pixel Touch ကို ဖယ်ရှားပြီးပါပြီ။ (Login က ဒီ Mac မှာ ကျန်ပါတယ်)"
  exit 0
fi

if [ "$(/bin/bash ./install.sh installed)" = "yes" ]; then
  say "Pixel Touch ထည့်ပြီးသားပါ — version $VER ကို ပြန်ထည့်ပါမယ် (Login နဲ့ setting တွေ မပျောက်ပါ)။"
fi

WANT="$(awk '$2=="PixelTouch.tar.gz"{print $1}' SHA256SUMS)"
[ -n "$WANT" ] || die "SHA256SUMS ထဲမှာ PixelTouch.tar.gz မပါပါ"
have_ok() { [ -f PixelTouch.tar.gz ] && [ "$(shasum -a 256 PixelTouch.tar.gz | cut -c1-64)" = "$WANT" ]; }

if have_ok; then
  ok "ဒေါင်းပြီးသား ဖိုင် ရှိပြီးသားပါ — ထပ်မဒေါင်းပါ"
else
  rm -f PixelTouch.tar.gz
  step "AI engine နဲ့ model တွေ ဒေါင်းနေပါတယ် (~1.1 GB)…"
  say "  လိုင်းပြတ်သွားရင် ဒီစာကြောင်းကို ပြန်ရိုက်ပါ — ပြတ်သွားတဲ့နေရာက ဆက်ဒေါင်းပါမယ်။"
  tries=0
  while :; do
    rc=0
    curl -fL --retry 10 --retry-delay 5 --retry-all-errors -C - \
      --progress-bar -o PixelTouch.tar.gz.part "$BASE/PixelTouch.tar.gz" || rc=$?
    [ $rc -eq 0 ] && break
    # 33: the server will not resume - start that file again from nothing
    [ $rc -eq 33 ] && rm -f PixelTouch.tar.gz.part
    tries=$((tries + 1))
    [ $tries -lt 20 ] || die "ဒေါင်းလို့ မပြီးပါ။ အင်တာနက် ပြန်ကောင်းရင် ဒီစာကြောင်းကို ပြန်ရိုက်ပါ — ဆက်ဒေါင်းပါမယ်။"
    say "  လိုင်းပြတ်သွားလို့ ဆက်ဒေါင်းနေပါတယ် ($tries)…"; sleep 5
  done
  mv PixelTouch.tar.gz.part PixelTouch.tar.gz
  if ! have_ok; then
    rm -f PixelTouch.tar.gz
    die "ဒေါင်းထားတဲ့ ဖိုင် မပြည့်စုံပါ။ ဒီစာကြောင်းကို ပြန်ရိုက်ပါ။"
  fi
  ok "ဒေါင်းပြီးပါပြီ"
fi
printf '%s\n' "$VER" > VERSION

close_photoshop

step "၁/၅  AI engine နဲ့ model တွေ ဖြည်နေပါတယ် (၁-၂ မိနစ်)…"
/bin/bash ./install.sh extract || die "ဖြည်လို့ မရပါ"
step "၂/၅  Photoshop ထဲ plugin ထည့်နေပါတယ်…"
/bin/bash ./install.sh plugin  || die "Plugin ထည့်လို့ မရပါ"
step "၃/၅  ပထမဆုံးအကြိမ် engine ကို ပြင်ဆင်နေပါတယ် (၁-၃ မိနစ်)…"
/bin/bash ./install.sh warm    || die "Engine ကို ပြင်ဆင်လို့ မရပါ"
step "၄/၅  Engine ကို စက်ဖွင့်တိုင်း အလိုလို run အောင် လုပ်နေပါတယ်…"
/bin/bash ./install.sh service || die "Engine service ထည့်လို့ မရပါ"
step "၅/၅  Engine စတင်နေပါတယ်…"
/bin/bash ./install.sh verify  || die "Engine မစနိုင်ပါ"

cd "$HOME"
rm -rf "$WORK"

say ""
ok "Pixel Touch $VER ထည့်သွင်းပြီးပါပြီ။"
say ""
say "  Photoshop ကို ဖွင့်ပြီး  Plugins → Pixel Touch  ကို ရွေးပါ။"
say "  ပထမဆုံးအကြိမ် AI model တွေ ဖွင့်ဖို့ စက္ကန့် ၃၀ လောက် စောင့်ရပါမယ်။"
say "  Terminal ကို ပိတ်လို့ ရပါပြီ။"
say ""
