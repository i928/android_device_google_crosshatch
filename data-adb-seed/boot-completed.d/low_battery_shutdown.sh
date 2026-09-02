#!/system/bin/sh
# Pixel 3 XL (crosshatch) charge limiter + emergency shutdown.
# Verified 2026-08-27: /sys/class/power_supply/battery/input_suspend exists
# and is writable (1 = stop charging, 0 = allow), unlike sunfish's smb5 path.
echo "battery script started at $(date)" >> /sdcard/Download/batteryscript.txt

CHARGING_SWITCH="/sys/class/power_supply/battery/input_suspend"

# Cable presence via 'present' nodes, not dumpsys's "AC powered" status --
# once charging is suspended the framework reports "AC powered: false" even
# though the cable is still in, which would make a dumpsys-based check think
# it's unplugged and re-enable charging, oscillating instead of holding at
# the limit. crosshatch has no ac/present node, only usb/wireless.
is_plugged() {
    for p in /sys/class/power_supply/usb/present \
             /sys/class/power_supply/wireless/present
    do
        [ -r "$p" ] && [ "$(cat "$p" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

while true; do
    LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    case "$LEVEL" in
        ''|*[!0-9]*) sleep 30; continue ;;
    esac

    if is_plugged; then
        PLUGGED=1
    else
        PLUGGED=0
    fi

    # 1. EMERGENCY SHUTDOWN BLOCK (Unplugged & under 20%)
    if [ "$LEVEL" -lt 20 ] && [ "$PLUGGED" -eq 0 ]; then
        svc power shutdown
        exit 0
    fi

    # 2. CHARGE LIMITER BLOCK (When charger is plugged in)
    if [ "$PLUGGED" -eq 1 ]; then
        # If battery reaches 80% or more, stop charging
        if [ "$LEVEL" -ge 80 ]; then
            echo 1 > "$CHARGING_SWITCH"

        # If battery drops back down to 70% or lower, resume charging
        elif [ "$LEVEL" -le 70 ]; then
            echo 0 > "$CHARGING_SWITCH"
        fi
    else
        # Force-enable charging when unplugged so it charges normally next time you plug it in
        echo 0 > "$CHARGING_SWITCH"
    fi

    # Check state every 30 seconds
    sleep 30
done
