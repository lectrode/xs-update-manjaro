# xs-update-manjaro

 ## ReadMe for Beta/Dev ([Switch to Stable](https://github.com/lectrode/xs-update-manjaro/tree/stable))

## Table of Contents
<details>
 <summary>↕</summary>

* [Summary](#summary "")
* [Suggested usage / Disclaimer](#suggested-usage-and-disclaimer "")
* [Execution Overview](#execution-overview "")
* [Supported Automatic Repair / Manual Changes](#supported-automatic-repair-and-manual-changes "")
* [Installation/Requirements](#installation-and-requirements "")
* [Supported AUR Helpers](#supported-aur-helpers "")
* [Configuration](#configuration "")
  * [=Sample Configuration=](#sample-config "")
  * [=Custom `makepkg` flags=](#custom-flags "")
  * [aur_1helper_str](#aur_1helper_str "")
  * [aur_aftercritical_bool](#aur_aftercritical_bool "")
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
  * [reboot_1enable_num](#reboot_1enable_num "")
  * [reboot_delayiflogin_bool](#reboot_delayiflogin_bool "")
  * [reboot_delay_num](#reboot_delay_num "")
  * [reboot_notifyrep_num](#reboot_notifyrep_num "")
  * [reboot_ignoreusers_str](#reboot_ignoreusers_str "")
  * [repair_db01_bool](#repair_db01_bool "")
  * [repair_manualpkg_bool](#repair_manualpkg_bool "")
  * [repair_pikaur01_bool](#repair_pikaur01_bool "")
  * [repair_pythonrebuild_bool](#repair_pythonrebuild_bool "")
  * [self_1enable_bool](#self_1enable_bool "")
  * [self_branch_str](#self_branch_str "")
  * [update_downgrades_bool](#update_downgrades_bool "")
  * [update_mirrors_freq](#update_mirrors_freq "")
  * [update_keys_freq](#update_keys_freq "")
</details>

## Summary

This is a highly configurable, **non-interactive** script for automating updates for Manjaro Linux. It supports updating the following:
* Main system packages (via `pacman`)
* AUR packages (via an [AUR helper](#supported-aur-helpers ""))
* Flatpak packages

Status Notifications are currently supported on the following Desktop Environments:
* Xfce
* KDE (requires [notify-desktop-git](https://aur.archlinux.org/packages/notify-desktop-git) for full notification support)
* Gnome ([permanent notifications extension](https://extensions.gnome.org/extension/41/permanent-notifications/ "") is recommended)
.


## Suggested Usage and Disclaimer:
No warranty or guarantee is included or implied. **Use at your own risk**.

Please do not use this script blindly. You should have a firm understanding of how to manually update your computer before using this. 
You can learn about updating your computer at the following:
* [Manjaro Wiki](https://wiki.manjaro.org/index.php?title=Main_Page#Software_Management_.2F_Applications)
* [Manjaro User Guide](https://manjaro.org/support/userguide/)
* [Tips for Updating Manjaro](https://forum.manjaro.org/t/root-tip-update-manjaro-the-smart-way/30979)

This is not a replacement for manually updating/maintaining your own computer, but a supplement. This script automates what it can, but updates needing manual steps (for example, merging .pacnew files) will still need those.
Some of the manual steps have been incorporated into this script, but your system(s) may require additional manual steps depending on what packages you have installed.

Always have external bootable media (like a flash drive with manjaro on it) available in case the system becomes unbootable.

## Execution Overview
<details>
<summary>↕</summary>

Overview of what the script does from start to finish. Some steps may be slightly out of order for readability.

### Initialization
<details>
 <summary>↕</summary>

* Define main functions
* Load Config
* Determine notification function (*config: [enable](#notify_1enable_bool ""), [manual selection](#notify_function_str "")*)
* Initialize logging (*config: [location](#main_logdir_str "")*)
* Load Persistent data (*config: [location](#main_perstdir_str "")*)
* Export Config and Persistent data files
* Perform checks:
  * Ensure only 1 instance is running
  * Wait up to 5 minutes for network connection
  * Check for script updates (*config: [enable](#self_1enable_bool ""), [branch](#self_branch_str "")*)
  * Wait up to 5 minutes for any already running instances of pacman/pikaur/apacman
  * Check for and remove db.lck
* Start background notification process
* Package cache cleanup (see [Cleanup Tasks](#cleanup-tasks "") for details)
</details>

### Update Official Repos
<details>
 <summary>↕</summary>

* Update mirrorlist (*config: [frequency](#update_mirrors_freq "")*)
  * `pacman-mirrors [--geoip || -c `[`$main_country_str`](#main_country_str "")`]`
  * Upon failure, falls back to `pacman-mirrors -g`


* Update package signature keys (*config: [frequency](#update_keys_freq "")*)
  * `pacman-key --refresh-keys`

* Check if packages are too old for script to update
  * Does not support installs with `xproto`<=7.0.31-1

* Update repo databases, download package updates
  * `pacman -Syyu[`[`u`](#update_downgrades_bool "")`]w --needed --noconfirm [--ignore `[`$main_ignorepkgs_str`](#main_ignorepkgs_str "")`]`

* Apply manual package changes (*config: [enable](#repair_manualpkg_bool "")*)
  * If `pacman`<5.2, switch to `pacman-static`
  * Required removal of known conflicting packages
  * If these actions fail, remaining repo and AUR packages are skipped

* Update System packages
  * `pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system`

* Check for package database errors (*config: [enable](#repair_db01_bool "")*)
  * For every package with errors:
    * create missing `files`/`desc`
    * reinstall with `pacman -S --noconfirm --overwrite=* packagename`


* Update packages from Official Repos
  * `pacman -Syyu[`[`u`](#update_downgrades_bool "")`] --needed --noconfirm [--ignore `[`$main_ignorepkgs_str`](#main_ignorepkgs_str "")`]`
  * If this fails, AUR updates are skipped

</details>

### Update AUR packages
<details>
 <summary>↕</summary>

* AUR updates are skipped after critical system package updates if [aur_aftercritical_bool](#aur_aftercritical_bool "") is false

* Determine available AUR helpers (*config: [frequency](#aur_update_freq ""), [manual selection](#aur_1helper_str "")*)
  * Check if pikaur is functional (*config: [enable repair](#repair_pikaur01_bool "")*)

* If AUR helper available/enabled, detect and rebuild AUR python packages that need it (*config: [enable python pkg rebuild](#repair_pythonrebuild_bool "")*)

* If selected, update AUR packages with `pikaur`
  * Update AUR packages with [custom flags](#custom-makepkg-flags-for-specific-aur-packages "") specified
  * Update remaining AUR packages
    * `pikaur -Sau[`[`u`](#update_downgrades_bool "")`] [`[`--devel`](#aur_devel_freq "")`] --needed --noconfirm --noprogressbar [--ignore `[`$main_ignorepkgs_str`](#main_ignorepkgs_str "")`]`

* If selected, update AUR packages with `apacman`
  * `apacman -Su[`[`u`](#update_downgrades_bool "")`] --auronly --needed --noconfirm [--ignore `[`$main_ignorepkgs_str`](#main_ignorepkgs_str "")`]`

</details>

### Cleanup Tasks
<details>
 <summary>↕</summary>

* All cleanup operations (*config: [enable](#cln_1enable_bool "")*)

  * Remove orphan packages (*config: [enable](#cln_orphan_bool "")*)
    * `pacman -Rnsc $(pacman -Qtdq) --noconfirm`

  * Package cache cleanup
    * Clean AUR package cache (*config: [enable](#cln_aurpkg_bool "")*)
      * `rm -rf /var/cache/apacman/pkg/*`
      * `rm -rf /var/cache/pikaur/pkg/*`
    * Clean AUR build cache (*config: [enable](#cln_aurbuild_bool "")*)
      * `rm -rf /var/cache/pikaur/aur_repos/*`
      * `rm -rf /var/cache/pikaur/build/*`
    * Clean pacman package cache
      * `paccache -rfqk`[`$cln_paccache_num`](#cln_paccache_num "")

</details>

### Update Flatpak
<details>
 <summary>↕</summary>

* Update `flatpak` packages (*config: [frequency](#flatpak_update_freq "")*)
  * `flatpak update -y`
</details>

### Final Actions
<details>
 <summary>↕</summary>

* Stop background notification process
* Determine final message
* Reboot proceedure if critical system packages were updated (*config: [enable](#reboot_1enable_num "")*)
  * Delay reboot if users are logged in (*config: [enable](#reboot_delayiflogin_bool ""), [ignore these users](#reboot_ignoreusers_str "")*)
    * Countdown to reboot (*config: [duration](#reboot_delay_num ""), [notification frequency](#reboot_notifyrep_num "")*)
  * `sync; reboot || systemctl --force reboot || systemctl --force --force reboot`
* Final message after non-critical update (*config: [duration](#notify_lastmsg_num "")*)
* Stop auto-update service and quit
</details>

----

</details>

## Supported Automatic Repair and Manual Changes
<details>
<summary>↕</summary>

### Automatic repair
This script supports detecting and repairing the following potential issues:
* [Package database errors](#repair_db01_bool "")
* [Non-functioning Pikaur](#repair_pikaur01_bool "")
* [AUR Python packages requiring rebuild after python 3.x update](#repair_pythonrebuild_bool "")

### Manual Changes
Every once in a while, updating Manjaro requires manual package changes to allow updates to succeed. This script [supports](#repair_manualpkg_bool "") automatically performing the following:
* Removal: `pyqt5-common`<=5.13.2-1, `engrampa-thunar-plugin`<=1.0-2
* Setup and use `pacman-static` if `pacman`<5.2

The oldest fresh install this script has successfully updated is Manjaro Xfce 17.1.7 (as of July of 2020). 
Oldest KDE and Gnome fresh installs are unknown, and not tested.

----

</details>

## Installation and Requirements
<details>
<summary>↕</summary>

### Dependencies:

This script requires these external tools/commands:
 * `coreutils`, `pacman`, `pacman-mirrors`, `grep`, `ping`

### Installation

1) Move script files to these locations:
````
ElectrodeXS.png         -> /usr/share/pixmaps/
auto-update.sh          -> /usr/share/xs/
xs-autoupdate.service   -> /etc/systemd/system/
xs-updatehelper.desktop -> /etc/xdg/autostart/
````

2) Make sure `auto-update.sh` is allowed to execute as a program

3) Enable running the auto-update script at startup (optional):
  * `sudo systemctl enable xs-autoupdate`

4) You can manually run the script with either:
  * `sudo systemctl start xs-autoupdate` (start in background)
  * `sudo /usr/share/xs/auto-update.sh` (watch logs in real-time)

----

</details>




## Supported AUR Helpers:
<details>
<summary>↕</summary>

If you want the script to automatically update packages from the AUR, it will need one of the following:

<details>
<summary>pikaur (recommended)</summary>

You can install [`pikaur`](https://github.com/actionless/pikaur) with another AUR helper, or install it directly with the following:
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
* Supports [skipping devel packages](#aur_devel_freq "")

Drawbacks:
* Does not support automatically importing PGP keys
 * (workaround: pass `--skippgpcheck` [custom flag](#custom-flags "") to packages that need it)
</details>

<details>
<summary>apacman (deprecated)</summary>

You can install [`apacman`](https://github.com/oshazard/apacman) (deprecated) with the following:
````
git clone https://aur.archlinux.org/apacman.git
pushd apacman
makepkg -si --noconfirm
popd
rm -rf apacman
#Replace old apacman with my fork with some fixes (not currently maintained)
sudo wget "https://raw.githubusercontent.com/lectrode/apacman/master/apacman" -O "/usr/bin/apacman"
sudo chmod +x "/usr/bin/apacman"
````
Features:
* Automatically imports PGP keys for packages

Drawbacks:
* No longer maintained upstream
* Does not support newer AUR packages
* Cannot pass custom makepkg flags
* Support will be removed in future version of script
</details>
</details>

----

## Configuration
<details>
 <summary>=Overview=</summary>

* By default settings are located at `/etc/xs/auto-update.conf`
* Settings file is (re)generated on every run
* Older settings will be converted to preserve preferences
* True and False are 1 and 0 respectively

* Settings location can be changed by exporting `xs_autoupdate_conf` environment variable
   * This needs absolute path and filename
   * Warning: whichever file is specified will be overwritten whenever the script runs
</details>

<details>
<summary><a name="sample-config"></a>=Sample configuration file=</summary>

* NOTE: Blank line at end may be required for last line to be parsed
````
aur_1helper_str=auto
aur_aftercritical_bool=0
aur_update_freq=3
aur_devel_freq=6
cln_1enable_bool=1
cln_aurbuild_bool=0
cln_aurpkg_bool=1
cln_orphan_bool=1
cln_paccache_num=1
flatpak_update_freq=3
main_country_str=
main_ignorepkgs_str=
main_logdir_str=/var/log/xs
main_perstdir_str=
main_testsite_str=www.google.com
notify_1enable_bool=1
notify_errors_bool=1
notify_function_str=auto
notify_lastmsg_num=20
notify_vsn_bool=0
reboot_1enable_num=1
reboot_delayiflogin_bool=1
reboot_delay_num=120
reboot_ignoreusers_str=nobody lightdm sddm gdm
reboot_notifyrep_num=10
repair_db01_bool=1
repair_manualpkg_bool=1
repair_pikaur01_bool=1
repair_pythonrebuild_bool=1
self_1enable_bool=1
self_branch_str=stable
update_downgrades_bool=1
update_keys_freq=30
update_mirrors_freq=1
zflag:dropbox,tor-browser=--skippgpcheck

````

</details>

<details>
<summary><a name="custom-flags"></a>=Custom makepkg flags for specific AUR packages=</summary>

* Requires pikaur
* You can add as many entries as you need
* All packages listed in one line will be updated at the same time
* Format: `zflag:package1,package2=--flag1,--flag2,--flag3`

</details>

### Individual Settings

<details>
 <summary><a name="aur_1helper_str"></a>aur_1helper_str</summary>

* Default: `auto`
* Specifies which AUR helper to use to update AUR packages
* Current valid values are: `auto`,`none`,`all`,`pikaur`,`apacman`
* `auto` will use an available AUR helper with the following preference: pikaur > apacman
* `all` will run every supported AUR helper found in this order: pikaur, apacman
* `none` will not use any AUR helper
</details>

<details>
 <summary><a name="aur_aftercritical_bool"></a>aur_aftercritical_bool</summary>

* Default: `0` (False)
* If set to false, script will skip AUR package updates after critical main system packages have been updated
* If set to true, script will proceed to update AUR packages, regardless of critical main package updates
</details>

<details>
<summary><a name="aur_update_freq"></a>aur_update_freq</summary>

* Default: `3`
* Every X days, update AUR packages (-1 disables all AUR updates, including devel)
</details>

<details>
<summary><a name="aur_devel_freq"></a>aur_devel_freq</summary>

* Default: `6`
* Every X days, update "devel" AUR packages (any package that ends in -git, -svn, etc) (-1 to disable)
* This setting only applies if AUR packages are updated with `pikaur`
</details>

----

<details>
<summary><a name="cln_1enable_bool"></a>cln_1enable_bool</summary>

* Default: `1` (True)
* If set to false, disables all cleanup steps
</details>

<details>
<summary><a name="cln_aurpkg_bool"></a>cln_aurpkg_bool</summary>

* Default: `1` (True)
* If this is True, all packages built from the AUR will be deleted when finished
</details>

<details>
<summary><a name="cln_aurbuild_bool"></a>cln_aurbuild_bool</summary>

* Default: `1` (True)
* If this is True, all AUR package build folders will be deleted when finished
</details>

<details>
<summary><a name="cln_orphan_bool"></a>cln_orphan_bool</summary>

* Default: `1` (True)
* If this is True, obsolete dependencies will be uninstalled when finished
</details>

<details>
<summary><a name="cln_paccache_num"></a>cln_paccache_num</summary>

* Default: `0`
* Specifies the number of official built packages to keep in cache
* If set to "-1" all official packages will be kept (cache is usually `/var/cache/pacman/pkg`)
</details>

----

<details>
<summary><a name="flatpak_update_freq"></a>flatpak_update_freq</summary>

 * Default: `3`
 * Every X days, check for Flatpak package updates (-1 to disable)
</details>

----

<details>
<summary><a name="notify_1enable_bool"></a>notify_1enable_bool</summary>

* Default: `1` (True)
* If true, enables status notifications to active users
</details>

<details>
<summary><a name="notify_function_str"></a>notify_function_str</summary>

* Default: `auto`
* Specifies which notification method to use
* Current valid values are: `auto`,`gdbus`,`desk`,`send`
  * `auto`: will automatically select the best method
  * `gdbus`: uses `gdbus` to create notifications (works on Xfce, Gnome)
  * `desk`: uses `notify-desktop` to create notifications (works on Xfce, KDE, and Gnome)
  * `send`: uses `notify-send` to create notifications (partial Xfce and KDE support - does not support replacing/dismissing existing notifications, which may result in notification spam)
* Note: if `desk` is specified (or if `auto` is specified and KDE is detected), and an AUR helper is configured, script will attempt to install [`notify-desktop-git`](https://aur.archlinux.org/packages/notify-desktop-git "") to provide this functionality
</details>

<details>
<summary><a name="notify_lastmsg_num"></a>notify_lastmsg_num</summary>

* Default: `20`
* Specifies how long (in seconds) the "System update finished" notification is visible before it expires.
* The "Kernel and/or drivers were updated" message does not expire, regardless of this setting
</details>

<details>
<summary><a name="notify_errors_bool"></a>notify_errors_bool</summary>

* Default: `1` (True)
* If true, script will state which tasks failed in the "System update finished" notification
</details>

<details>
<summary><a name="notify_vsn_bool"></a>notify_vsn_bool</summary>

* Default: `0` (False)
* If true, the version number of the script will be included in notifications
</details>

----

<details>
<summary><a name="main_ignorepkgs_str"></a>main_ignorepkgs_str</summary>

* Default: (blank)
* Packages (if any) to ignore, separated by spaces (these are in addition to those stored in pacman.conf)
</details>

<details>
<summary><a name="main_logdir_str"></a>main_logdir_str</summary>

* Default: `/var/log/xs`
* Defines the directory where the log will be output
</details>

<details>
<summary><a name="main_perstdir_str"></a>main_perstdir_str</summary>

* Default: (blank)
* Defines the directory where persistent timestamps are stored. If blank, uses main_logdir_str
</details>

<details>
<summary><a name="main_country_str"></a>main_country_str</summary>

* Default: (blank)
* If blank, `pacman-mirrors --geoip` is used
* Countries separated by commas from which to pull updates
* See output of `pacman-mirrors -l` for supported values
</details>

<details>
<summary><a name="main_testsite_str"></a>main_testsite_str</summary>

* Default: `www.google.com`
* Script checks if there is internet access by attempting to ping this address
* Can also be an IP address
</details>

----

<details>
<summary><a name="reboot_1enable_num"></a>reboot_1enable_num</summary>

 * Default: `1`
 * -1: Disable script reboot in all cases
 *  0: Allow script reboot only if rebooting normally may not be possible (system may be in critical state after critical package update)
 *  1: Always allow script to reboot after critical system packages have been updated
</details>

<details>
<summary><a name="reboot_delayiflogin_bool"></a>reboot_delayiflogin_bool</summary>

 * Default: `1` (True)
 * If true, the reboot will be delayed *only if* a user is logged in. If false, there will always be a delay
</details>

<details>
<summary><a name="reboot_delay_num"></a>reboot_delay_num</summary>

 * Default: `120`
 * Delay in seconds to wait before rebooting the computer
</details>

<details>
<summary><a name="reboot_notifyrep_num"></a>reboot_notifyrep_num</summary>

 * Default: `10`
 * Reboot notification is updated every X seconds
 * Works best if reboot_delay_num is evenly divisible by this
</details>

<details>
<summary><a name="reboot_ignoreusers_str"></a>reboot_ignoreusers_str</summary>

 * Default: `nobody lightdm sddm gdm`
 * List of users separated by spaces
 * These users will not trigger the reboot delay even if they are logged on
</details>

----

<details>
<summary><a name="repair_db01_bool"></a>repair_db01_bool</summary>

 * Default: `1` (True)
 * If true, the script will detect and attempt to repair missing "desc"/"files" files in package database
 * NOTE: It does this by creating the missing files and re-installing the package(s) with `overwrite=*` specified

</details>

<details>
<summary><a name="repair_manualpkg_bool"></a>repair_manualpkg_bool</summary>

 * Default: `1` (True)
 * If true, script will check for and perform critical package changes required for continued updates
 * See [Automatic Repair](#supported-automatic-repair-and-manual-changes "") for specific package changes the script supports
</details>

<details>
<summary><a name="repair_pikaur01_bool"></a>repair_pikaur01_bool</summary>

 * Default: `1` (True)
 * If true, the script will attempt to re-install pikaur if it is not functioning
 * NOTE: Specifically needed if python is updated
</details>

<details>
<summary><a name="repair_pythonrebuild_bool"></a>repair_pythonrebuild_bool</summary>

 * Default: `1` (True)
 * If true, the script will attempt to rebuild AUR python packages after python update
</details>

----

<details>
<summary><a name="self_1enable_bool"></a>self_1enable_bool</summary>

* Default: `1` (True)
* If true, script checks for updates for itself ("self-updates")
</details>

<details>
<summary><a name="self_branch_str"></a>self_branch_str</summary>

* Default: `stable`
* Script update branch (requires `self_1enable_bool` be True)
* Current valid values are: `stable`, `beta`
</details>

----

<details>
<summary><a name="update_downgrades_bool"></a>update_downgrades_bool</summary>

* Default: `1` (True)
* If true, allows pacman to downgrade packages if remote packages are a lesser version than installed
</details>

<details>
<summary><a name="update_mirrors_freq"></a>update_mirrors_freq</summary>

* Default: `0`
* Every X days, refreshes mirror list before checking for package updates (-1 to disable)
</details>

<details>
<summary><a name="update_keys_freq"></a>update_keys_freq</summary>

* Default: `30`
* Every X days, runs `pacman-key --refresh-keys` before checking for package updates (-1 to disable)
</details>



<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />
<br />



