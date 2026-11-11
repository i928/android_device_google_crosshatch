#!/system/bin/sh
# Osaifu-Keitai (com.felicanetworks.mfm.main) is the launcher app of the FeliCa
# stack, which only works on the Japanese models (G013B Pixel 3, G013D Pixel 3
# XL). The stack ships on every model, and on the others the icon is just an
# app that cannot do anything, so disable it there for user 0.
#
# Once per /data (marker), so someone who enables it again keeps it. Only the
# launcher app: the other FeliCa packages have no icon.
#
# Seeded into /data/adb/boot-completed.d by init.data-adb-seed.rc; KernelSU runs
# it as root after boot completes.
MARK=/data/adb/.felica_hide.done
[ -f "$MARK" ] && exit 0
case "$(getprop ro.boot.hardware.sku)" in
G013B|G013D) : > "$MARK"; exit 0 ;;
esac
PKG=com.felicanetworks.mfm.main
pm path "$PKG" >/dev/null 2>&1 || exit 0
echo "$(date '+%F %T') $PKG: $(pm disable-user --user 0 "$PKG" 2>&1)" >> /data/adb/felica_hide.log
: > "$MARK"
