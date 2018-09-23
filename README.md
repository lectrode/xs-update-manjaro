# xs-update-manjaro

## Contents:
* [Summary](#summary "")
* [Suggested usage / Disclaimer](#suggested-usage-and-disclaimer "")
* [Detailed Description](#detailed-description "")
* [Installation](#installation "")
* [Dependencies](#dependencies "")
* [Supported AUR Helpers](#supported-aur-helpers "")
* [Configuration](#configuration "")
  * [aur_1helper_str](#aur_1helper_str "")
  * [aur_devel_bool](#aur_devel_bool "")
  * [notify_lastmsg_num](#notify_lastmsg_num "")
  * [bool_detectErrors](#bool_detecterrors "")
  * [bool_Downgrades](#bool_downgrades "")
  * [bool_notifyMe](#bool_notifyme "")
  * [bool_updateFlatpak](#bool_updateflatpak "")
  * [bool_updateKeys](#bool_updatekeys "")
  * [str_cleanLevel](#str_cleanlevel "")
  * [str_ignorePackages](#str_ignorepackages "")
  * [str_log_d](#str_log_d "")
  * [str_mirrorCountry](#str_mirrorcountry "")
  * [str_testSite](#str_testsite "")
* [Custom makepkg flags for specific AUR packages](#custom-makepkg-flags-for-specific-aur-packages "")
* [Sample configuration file](#sample-configuration-file "")

### Warning: this script is intended for use by advanced users only

## Summary
This performs a full and automatic update of all packages using `pacman`. If a supported [AUR helper](#supported-aur-helpers "") is installed and enabled, this will also update all AUR packages. If [notifications](#bool_notifyme "") are enabled, status notifications are sent to any active users. 

## Suggested Usage and Disclaimer:
This is not a replacement for manually updating/maintaining your own computer, but a supplement. This script automates what it can, but updates needing manual steps (for example, merging .pacnew files) will still need those. If not used properly, this script may "break" your system. For example, if the computer is restarted while the script is updating core components, the computer may no longer be able to boot. No warranty or guarantee is included or implied. **Use at your own risk**. 

Personally, I use this script to update my personal computer, as well as help manage remote computers. If manual steps are required, I'll take care of those manually on the computers. Otherwise (as is usually the case), this script will keep those updated.

## Detailed Description
This script requires root access and is made to run automatically at startup, although it can be run manually or on a schedule as well. It logs everything it does in [`$str_log_d`](#str_log_d "")`/auto-update.log`. If it detects that kernel or driver packages were updated (any package with `linux[0-9]{2,3}` in the name, with some exceptions), it will include the date in the log name to keep it for future reference, as well as notify the user that a restart is needed (it will not automatically restart the computer!). If a restart is needed, waiting to restart may cause some applications to have issues.

After performing a number of "checks" (make sure script isn't already running, check for internet connection, check for running instances of pacman/apacman, remove db.lck if it exists and nothing is updating, etc), this script primarily runs the following commands (in this order) to update the computer:
````
pacman-mirrors [--geoip || -c $str_mirrorCountry] # Update mirrors
pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system # Update system packages
pacman-key --refresh-keys # Can be disabled via bool_updateKeys
sync
pacman -Syyu[u] --needed --noconfirm [ignored packages]

pikaur -Sau[u] [--devel] --needed --noconfirm --noprogressbar [ignored packages] # Can be disabled via aur_1helper_str
apacman -Su[u] --auronly --needed --noconfirm [ignored packages] # Can be disabled via aur_1helper_str

pacman -Rnsc $(pacman -Qtdq) --noconfirm # Removes orphan packages no longer required
````

## Installation:

(Only required if you intend to have the script run at startup)

Move the files to the proper locations:
````
ElectrodeXS.png         -> /usr/share/pixmaps/
auto-update.sh          -> /usr/share/xs/
xs-autoupdate.service   -> /etc/systemd/system/
xs-updatehelper.desktop -> /etc/xdg/autostart/
````

Make sure auto-update.sh is allowed to execute as a program
Lastly, run this to enable the auto-update startup service:
````systemctl enable xs-autoupdate````


## Dependencies:

This script requires these external tools/commands:
pacman, paccache, xfce4-notifyd, grep, ping


## Supported AUR Helpers:

If you want the script to automatically update packages from the AUR, it will need either [`pikaur`](https://github.com/actionless/pikaur) or `apacman` (deprecated).

### pikaur:

You can install `pikaur` with another AUR helper, or install it directly with the following:
```
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/pikaur.git
cd pikaur
makepkg -fsri
```

Features:
* Actively developed/maintained
* Supports latest PKGBUILD format and AUR features
* Introduces the ability to pass [specific `makepkg` flags](#custom-makepkg-flags-for-specific-aur-packages "") to packages

Drawbacks:
* Does not support automatically importing PGP keys
 * (workaround: pass `--skippgpcheck` to packages that need it)

### apacman (deprecated):

You can install `apacman` (deprecated) with the following:
````
git clone https://aur.archlinux.org/apacman.git
pushd apacman
makepkg -si --noconfirm
popd
rm -rf apacman
#Replace old apacman with my fork with fixes
sudo wget "https://raw.githubusercontent.com/lectrode/apacman/master/apacman" -O "/usr/bin/apacman"
sudo chmod +x "/usr/bin/apacman"
````
Features:
* Automatically imports PGP keys for packages
* Stable

Drawbacks:
* No longer maintained
* Does not support newer AUR packages
* Cannot pass custom makepkg flags


## Configuration:

* Settings stored in /etc/xs/auto-update.conf
* Settings file is generated automatically on first run
* Defaults are recommended for general use
* True and False are 1 and 0 respectively

### aur_1helper_str
* Default: `auto`
* Specifies which AUR helper to use to update AUR packages
* Current valid values are: auto,none,all,pikaur,apacman
* `auto` will use an available AUR helper with the following preference: pikaur > apacman
* `all` will run every supported AUR helper found in this order: pikaur, apacman
* `none` will not use any AUR helper

### notify_lastmsg_num
* Default: 20
* Specifies how long (in seconds) the final "System update finished" notification is visible before it expires.
* The "Kernel and/or drivers were updated" message does not expire, regardless of this setting
* Requires `bool_notifyMe` to be True

### aur_devel_bool
* Default: True
* If true, updates "devel" AUR packages (any package that ends in -git, -svn, etc)
* You may want to disable this and 

### bool_detectErrors
* Default: True
* If true, script attempts to detect errors. If any, includes message "Some packages encountered errors" in notification

### bool_Downgrades
* Default: True
* If true, allows pacman to downgrade packages if remote packages are a lesser version than installed

### bool_notifyMe
* Default: True
* If true, enables status notifications via `notify-send` to active users

### bool_updateFlatpak
 * Default: True
 * Check for Flatpak package updates

### bool_updateKeys
* Default: True
* If true, runs `pacman-key --refresh-keys` before checking for package updates

### str_cleanLevel
* Default: `high`
* high: runs `paccache -rvk0` and empties AUR Helper cache
* low: runs `paccache -rvk2` and empties AUR Helper cache
* off: Takes no action

### str_ignorePackages
* Default: (blank)
* Packages (if any) to ignore, separated by spaces (these are in addition to those stored in pacman.conf)

### str_log_d
* Default: "/var/log/xs"
* Defines the directory where the log will be output

### str_mirrorCountry
 * Default: (blank)
 * If blank, `pacman-mirrors --geoip` is used
 * Countries separated by commas from which to pull updates

### str_testSite
* Default: `www.google.com`
* Script checks if there is internet access by attempting to ping this site


## Custom makepkg flags for specific AUR packages
* Requires pikaur
* You can add as many entries as you need
* All packages listed in one line will be updated at the same time
* Format: zflag:package1,package2=--flag1,--flag2,--flag3


## Sample configuration file
NOTE: Needs to be placed at /etc/xs/auto-update.conf
NOTE: Blank line at end is required for last line to be parsed
````
bool_detectErrors=1
bool_Downgrades=1
bool_notifyMe=1
aur_devel_bool=1
bool_updateFlatpak=1
bool_updateKeys=1
notify_lastmsg_num=20
aur_1helper_str=auto
str_cleanLevel=high
str_ignorePackages=
str_log_d=/var/log/xs
str_mirrorCountry=
str_testSite=www.google.com
zflag:libc++abi,libc++=--skippgpcheck,--nocheck
zflag:tor-browser-en=--skippgpcheck

````

