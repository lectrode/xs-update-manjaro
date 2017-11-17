# xs-update-manjaro
Update script for Manjaro

### Warning: this script is intended for use by advanced users only

## Summary
This performs a full and automatic update of all packages using `pacman`. If `apacman` is installed, this will also update all AUR packages. On systems with `notify-send` available, status notifications are sent to any active users.

## Suggested usage / Disclaimer:
This is not a replacement for manually updating/maintaining your own computer, but a supplement. This script automates what it can, but updates needing manual steps (for example, confirming the replacement of packages) will still need those. If not used properly, this script may "break" your system. For example, if the computer is restarted while the script is updating core components, the computer may no longer be able to boot. No warranty or guarantee is included or implied. **Use at your own risk**. 

Personally, I use this script to update my personal computer, as well as help manage remote computers. I frequently update an identical machine, and if manual steps are required, I'll take care of those manually on the remote computers. Otherwise (as is usually the case), this script will keep those updated just like I keep the clone updated.

## Detailed
This script requires root access and is made to run automatically at startup, although it can be run manually or on a schedule as well. It logs everything it does in `/var/log/xs/auto-update.log`. If it detects that kernel or driver packages were updated (any package with `linux[0-9]{2,3}` in the name, with some exceptions), it will include the date in the log name to keep it for future reference, as well as notify the user that a restart is needed (it will not automatically restart the computer!). If a restart is needed, waiting to restart may cause some applications to have issues.

After performing a number of "checks" (make sure script isn't already running, check for internet connection, check for running instances of pacman/apacman, remove db.lck if it exists and nothing is updating, etc), this script primarily runs the following commands (in this order) to update the computer:
````
pacman-mirrors -g # Update mirrors
pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system # Update system packages
pacman-key --refresh-keys
pacman-optimize
sync
[pacman||apacman] -Syyu[u] --needed --noconfirm [ignored packages] # Uses pacman or apacman to update packages on system
pacman -Rnsc $(pacman -Qtdq) --noconfirm # Removes orphan packages no longer required
````



## Configuration:

* Settings stored in /etc/xs/auto-update.conf
* Settings file is generated automatically on first run
* Defaults are recommended for general use

### bool_Downgrades
* Default: True
* If true, allows pacman to downgrade packages if remote packages are a lesser version than installed

### bool_detectErrors
* Default: True
* If true, script attempts to detect errors. If any, includes message "Some packages encountered errors" in notification

### bool_updateKeys
* Default: True
* If true, runs `pacman-key --refresh-keys` before checking for package updates

### bool_updateFlatpak
 * Default: True
 * Check for Flatpak package updates

### bool_notifyMe
* Default: True
* If true, enables status notifications via `notify-send` to active users

### str_ignorePackages
* Default: (blank)
* Packages (if any) to ignore, separated by spaces (these are in addition to those stored in pacman.conf)

### str_mirrorCountry
 * Default: (blank)
 * If blank, `pacman-mirrors --geoip` is used
 * Countries separated by commas from which to pull updates

### str_testSite
* Default: `www.google.com`
* Script checks if there is internet access by attempting to ping this site

### str_cleanLevel
* Default: `high`
* high: runs `paccache -rvk0` and empties /var/cache/apacman/pkg
* low: runs `paccache -rvk2` and empties /var/cache/apacman/pkg
* off: Takes no action

### str_log_d
* Default: "/var/log/xs"
* Defines the directory where the log will be output



## Sample configuration file (/etc/xs/auto-update.conf)
````
bool_Downgrades=1
bool_detectErrors=1
bool_updateKeys=1
bool_updateFlatpak=1
bool_notifyMe=1
str_ignorePackages=
str_mirrorCountry=
str_testSite=www.google.com
str_cleanLevel=high
str_log_d=/var/log/xs
````
