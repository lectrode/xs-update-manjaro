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
  * [aur_update_freq](#aur_update_freq "")
  * [aur_devel_freq](#aur_devel_freq "")
  * [cln_1enable_bool](#cln_1enable_bool "")
  * [cln_aurpkg_bool](#cln_aurpkg_bool "")
  * [cln_aurbuild_bool](#cln_aurbuild_bool "")
  * [cln_orphan_bool](#cln_orphan_bool "")
  * [cln_paccache_num](#cln_paccache_num "")
  * [flatpak_update_freq](#flatpak_update_freq "")
  * [notify_1enable_bool](#notify_1enable_bool "")
  * [notify_function_str](#notify_function_str "")
  * [notify_lastmsg_num](#notify_lastmsg_num "")
  * [notify_errors_bool](#notify_errors_bool "")
  * [notify_vsn_bool](#notify_vsn_bool "")
  * [main_ignorepkgs_str](#main_ignorepkgs_str "")
  * [main_logdir_str](#main_logdir_str "")
  * [main_perstdir_str](#main_perstdir_str "")
  * [main_country_str](#main_country_str "")
  * [main_testsite_str](#main_testsite_str "")
  * [reboot_1enable_bool](#reboot_1enable_bool "")
  * [reboot_delayiflogin_bool](#reboot_delayiflogin_bool "")
  * [reboot_delay_num](#reboot_delay_num "")
  * [reboot_notifyrep_num](#reboot_notifyrep_num "")
  * [reboot_ignoreusers_str](#reboot_ignoreusers_str "")
  * [self_1enable_bool](#self_1enable_bool "")
  * [self_branch_str](#self_1enable_bool "")
  * [update_downgrades_bool](#update_downgrades_bool "")
  * [update_mirrors_freq](#update_mirrors_freq "")
  * [update_keys_freq](#update_keys_freq "")
* [Custom makepkg flags for specific AUR packages](#custom-makepkg-flags-for-specific-aur-packages "")
* [Sample configuration file](#sample-configuration-file "")

### Warning: this script is intended for use by advanced users only

## Summary
This performs a full and automatic update of all packages using `pacman`. If a supported [AUR helper](#supported-aur-helpers "") is installed and [enabled](#aur_1helper_str ""), this will also update all AUR packages. If flatpak is installed and [enabled](#flatpak_update_freq ""), this will also update flatpak packages. If notifications are [enabled](#notify_1enable_bool ""), status notifications are sent to any active users (supports Xfce, KDE, and Gnome). If using Gnome, I recommend installing the [permanent notifications extension](https://extensions.gnome.org/extension/41/permanent-notifications/ "").

## Suggested Usage and Disclaimer:
This is not a replacement for manually updating/maintaining your own computer, but a supplement. This script automates what it can, but updates needing manual steps (for example, merging .pacnew files) will still need those. If not used properly, this script may "break" your system. For example, if the computer is restarted while the script is updating core components, the computer may no longer be able to boot. No warranty or guarantee is included or implied. **Use at your own risk**.

Personally, I use this script to update my personal computer, as well as help manage remote computers. If manual steps are required, I'll take care of those manually on the computers. Otherwise (as is usually the case), this script will keep those updated.

## Detailed Description
This script requires root access and is made to run automatically at startup, although it can be run manually or on a schedule as well. It logs everything it does in [`$main_logdir_str`](#main_logdir_str "")`/auto-update.log`. If it detects that kernel or systemd packages were updated, it will include the date in the log name to keep it for future reference, as well as notify the user that a restart is needed. If automatic reboot is [enabled](#reboot_1enable_bool ""), it will also automatically reboot the computer (this is disabled by default). If a restart is needed, waiting to restart may cause some applications to have issues.

After performing a number of "checks" (make sure script isn't already running, check for internet connection, check for running instances of pacman/apacman, remove db.lck if it exists and nothing is updating, etc), this script primarily runs the following commands (if they are enabled) to update the computer:
````
pacman-mirrors [--geoip || -c $main_country_str] # Update mirrors
pacman-key --refresh-keys # Update package signature keys
pacman -Syy --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system # Update system packages
pacman -Su[u] --needed --noconfirm [ignored packages] # Update packages from official repos

pikaur -Sau[u] [--devel] --needed --noconfirm --noprogressbar [ignored packages] # Update AUR packages
apacman -Su[u] --auronly --needed --noconfirm [ignored packages] # Update AUR packages

flatpak update -y # Update Flatpak packages

pacman -Rnsc $(pacman -Qtdq) --noconfirm # Removes orphan packages no longer required
````

## Installation:

Move the files to the proper locations:
````
ElectrodeXS.png         -> /usr/share/pixmaps/
auto-update.sh          -> /usr/share/xs/
xs-autoupdate.service   -> /etc/systemd/system/
xs-updatehelper.desktop -> /etc/xdg/autostart/
````

Make sure auto-update.sh is allowed to execute as a program
Lastly, run this to enable running the auto-update script at startup:
`sudo systemctl enable xs-autoupdate`


## Dependencies:

This script requires these external tools/commands:
coreutils, pacman, paccache, xfce4-notifyd, grep, ping


## Supported AUR Helpers:

If you want the script to automatically update packages from the AUR, it will need either [`pikaur`](https://github.com/actionless/pikaur) (recommended) or `apacman` (deprecated).

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
* Introduces the ability to pass [specific makepkg flags](#custom-makepkg-flags-for-specific-aur-packages "") to packages

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

* By default settings are located at /etc/xs/auto-update.conf
* Settings file is (re)generated on every run
* Older settings will be converted to preserve preferences
* True and False are 1 and 0 respectively

* Settings location can be changed by exporting `xs_autoupdate_conf` environment variable
   * This needs absolute path and filename
   * Warning: whichever file is specified will be overwritten whenever the script runs

### aur_1helper_str
* Default: `auto`
* Specifies which AUR helper to use to update AUR packages
* Current valid values are: `auto`,`none`,`all`,`pikaur`,`apacman`
* `auto` will use an available AUR helper with the following preference: pikaur > apacman
* `all` will run every supported AUR helper found in this order: pikaur, apacman
* `none` will not use any AUR helper

### aur_update_freq
* Default: `3`
* Every X days, update AUR packages (-1 disables all AUR updates, including devel)

### aur_devel_freq
* Default: `6`
* Every X days, update "devel" AUR packages (any package that ends in -git, -svn, etc) (-1 to disable)

### cln_1enable_bool
* Default: `1` (True)
* If set to false, disables all cleanup steps

### cln_aurpkg_bool
* Default: `1` (True)
* If this is True, all packages built from the AUR will be deleted when finished

### cln_aurbuild_bool
* Default: `1` (True)
* If this is True, all AUR package build folders will be deleted when finished

### cln_orphan_bool
* Default: `1` (True)
* If this is True, obsolete dependencies will be uninstalled when finished

### cln_paccache_num
* Default: `0`
* Specifies the number of official built packages to keep in cache
* If set to "-1" all official packages will be kept (cache is usually `/var/cache/pacman/pkg`)

### flatpak_update_freq
 * Default: `3`
 * Every X days, check for Flatpak package updates (-1 to disable)
 
### notify_1enable_bool
* Default: `1` (True)
* If true, enables status notifications via `notify-send` to active users

### notify_function_str
* Default: `auto`
* Specifies which notification method to use
* Current valid values are: `auto`,`gdbus`,`desk`,`send`
  * `auto`: will automatically select the best method
  * `gdbus`: uses `gdbus` to create notifications (works on Xfce, Gnome)
  * `desk`: uses `notify-desktop` to create notifications (works on Xfce, KDE, and Gnome)
  * `send`: uses legacy `notify-send` to create notifications (works on Xfce)
* Note: if `auto` or `desk` is specified, and an AUR helper is configured, and KDE is detected, script will attempt to install [`notify-desktop-git`](https://aur.archlinux.org/packages/notify-desktop-git "") to provide this functionality

### notify_lastmsg_num
* Default: `20`
* Specifies how long (in seconds) the final "System update finished" notification is visible before it expires.
* The "Kernel and/or drivers were updated" message does not expire, regardless of this setting
* Requires `notify_1enable_bool` to be True

### notify_errors_bool
* Default: `1` (True)
* If true, script attempts to detect errors. If any, includes message "Some packages encountered errors" in notification

### notify_vsn_bool
* Default: `0` (False)
* If true, the version number of the script will be included in notifications

### main_ignorepkgs_str
* Default: (blank)
* Packages (if any) to ignore, separated by spaces (these are in addition to those stored in pacman.conf)

### main_logdir_str
* Default: `/var/log/xs`
* Defines the directory where the log will be output

### main_perstdir_str
* Default: (blank)
* Defines the directory where persistant timestamps are stored. If blank, uses main_logdir_str

### main_country_str
* Default: (blank)
* If blank, `pacman-mirrors --geoip` is used
* Countries separated by commas from which to pull updates
* See output of `pacman-mirrors -l` for supported values

### reboot_1enable_bool
 * Default: `0` (False)
 * If true, script will automatically reboot if it detects the kernel and/or systemd have been updated


### reboot_delayiflogin_bool
 * Default: `1` (True)
 * If true, the reboot will be delayed *only if* a user is logged in. If false, there will always be a delay

### reboot_delay_num
 * Default: `120`
 * Delay in seconds to wait before rebooting the computer


### reboot_notifyrep_num
 * Default: `10`
 * Reboot notification is updated every X seconds
 * Works best if reboot_delay_num is evenly divisible by this


### reboot_ignoreusers_str
 * Default: `nobody lightdm sddm gdm`
 * List of users separated by spaces
 * These users will not trigger the reboot delay even if they are logged on


### self_1enable_bool
* Default: `1` (True)
* If true, script checks for updates for itself ("self-updates")

### self_branch_str
* Default: `stable`
* Script update branch (requires `self_1enable_bool` be True)
* Current valid values are: `stable`, `beta`

### main_testsite_str
* Default: `www.google.com`
* Script checks if there is internet access by attempting to ping this address
* Can also be an IP address

### update_downgrades_bool
* Default: `1` (True)
* If true, allows pacman to downgrade packages if remote packages are a lesser version than installed

### update_mirrors_freq
* Default: `0`
* Every X days, refreshes mirror list before checking for package updates (-1 to disable)

### update_keys_freq
* Default: `30`
* Every X days, runs `pacman-key --refresh-keys` before checking for package updates (-1 to disable)


## Custom makepkg flags for specific AUR packages
* Requires pikaur
* You can add as many entries as you need
* All packages listed in one line will be updated at the same time
* Format: `zflag:package1,package2=--flag1,--flag2,--flag3`


## Sample configuration file
* NOTE: Blank line at end is required for last line to be parsed
````
aur_1helper_str=auto
aur_update_freq=3
aur_devel_freq=6
cln_1enable_bool=1
cln_aurbuild_bool=1
cln_aurpkg_bool=1
cln_orphan_bool=1
cln_paccache_num=0
flatpak_1enable_bool=1
main_ignorePackages_str=
main_logdir_str=/var/log/xs
main_country_str=
main_testSite_str=www.google.com
notify_1enable_bool=1
notify_function_str=auto
notify_lastmsg_num=20
notify_errors_bool=1
reboot_1enable_bool=0
reboot_delayiflogin_bool=1
reboot_delay_num=120
reboot_notifyrep_num=10
reboot_ignoreusers_str=nobody lightdm sddm gdm
self_1enable_bool=1
self_branch_str=stable
update_downgrades_bool=1
update_keys_bool=1
zflag:tor-browser=--skippgpcheck

````





