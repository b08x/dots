#!/bin/bash

# Alternative to XDG Desktop Global Shortcuts Portal
# https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html
#
# The XDG Desktop Global Shortcuts Portal is a fairly recent addition that is
# still not widely supported across desktop environments. For systems where the
# portal is not available, this script provides a manual way to trigger the
# application via D-Bus, allowing users to connect it with their system's
# custom keyboard shortcuts (or other automation tools).

gdbus call \
    --session \
    --dest io.speedofsound.SpeedOfSound \
    --object-path /io/speedofsound/SpeedOfSound \
    --method org.gtk.Actions.Activate "trigger" [] {}

# --- Notification -----------------------------------------------------------------
# Tell the user the action was triggered. Uses the freedesktop.org
# Notifications spec on the session bus (signature susssasa{sv}i).
# D-Bus docs note the session bus is addressed via DBUS_SESSION_BUS_ADDRESS,
# so DBUS_SESSION_BUS_ADDRESS isn't needed explicitly here.
if command -v notify-send >/dev/null 2>&1; then
    # libnotify is simplest if available (same org.freedesktop.Notifications spec)
    notify-send -a "SpeedOfSound" -i audio-volume-high \
        "SpeedOfSound triggered" "Global shortcut activation sent" \
        --hint=string:transient:true
else
    # Plain gdbus call to the org.freedesktop.Notifications daemon (e.g. dunst)
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "SpeedOfSound" \
        0 \
        "audio-volume-high" \
        "SpeedOfSound triggered" \
        "Global shortcut activation sent" \
        [] \
        {} \
        3000
fi
