#!/bin/sh

case $1'' in
'status')
    printf '{\"text\":\"%s\",\"tooltip\":\"%s\"}' "$(dnf check-update -q 2>/dev/null | grep -c '')" "$(dnf check-update -q 2>/dev/null | awk 1 ORS='\\n' | sed 's/\\n$//')"
    ;;
'check')
    [ $(dnf check-update -q 2>/dev/null | grep -c '') -gt 0 ]
    exit $?
    ;;
'upgrade')
    if [ -x "$(command -v topgrade)" ]; then
        xdg-terminal-exec topgrade
    elif [ -x "$(command -v dnf5)" ]; then
        xdg-terminal-exec dnf5 upgrade -y
    else
        xdg-terminal-exec dnf upgrade -y
    fi
    ;;
esac
