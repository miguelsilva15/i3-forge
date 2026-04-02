#!/bin/bash

chosen=$(printf "  Shutdown\n  Restart\n  Suspend\n  Lock\n  Logout" | rofi -dmenu -i -p "Power" -theme ~/.config/rofi/starlight.rasi)

case "$chosen" in
    "  Shutdown") systemctl poweroff ;;
    "  Restart")  systemctl reboot ;;
    "  Suspend")  systemctl suspend ;;
    "  Lock")     i3lock -i ~/Wallpapers/w01.png ;;
    "  Logout")   i3-msg exit ;;
esac
