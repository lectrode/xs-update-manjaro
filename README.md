# xs-update-manjaro

 ## ReadMe for Stable ([Switch to Beta](https://github.com/lectrode/xs-update-manjaro))

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
  * [cln_aurpkg_num](#cln_aurpkg_num "")
  * [cln_aurbuild_bool](#cln_aurbuild_bool "")
  * [cln_orphan_bool](#cln_orphan_bool "")
  * [cln_flatpakorphan_bool](#cln_flatpakorphan_bool "")
  * [cln_paccache_num](#cln_paccache_num "")
  * [flatpak_update_freq](#flatpak_update_freq "")
  * [notify_1enable_bool](#notify_1enable_bool "")
  * [notify_function_str](#notify_function_str "")
  * [notify_lastmsg_num](#notify_lastmsg_num "")
  * [notify_errors_bool](#notify_errors_bool "")
  * [notify_vsn_bool](#notify_vsn_bool "")
  * [main_ignorepkgs_str](#main_ignorepkgs_str "")
  * [main_systempkgs_str](#main_systempkgs_str "")
  * [main_inhibit_bool](#main_inhibit_bool "")
  * [main_logdir_str](#main_logdir_str "")
  * [main_perstdir_str](#main_perstdir_str "")
  * [main_country_str](#main_country_str "")
  * [main_testsite_str](#main_testsite_str "")
  * [reboot_1enable_num](#reboot_1enable_num "")
  * [reboot_action_str](#reboot_action_str "")
  * [reboot_delayiflogin_bool](#reboot_delayiflogin_bool "")
  * [reboot_delay_num](#reboot_delay_num "")
  * [reboot_notifyrep_num](#reboot_notifyrep_num "")
  * [reboot_ignoreusers_str](#reboot_ignoreusers_str "")
  * [repair_1enable_bool](#repair_1enable_bool "")
  * [repair_db01_bool](#repair_db01_bool "")
  * [repair_db02_bool](#repair_db02_bool "")
  * [repair_keyringpkg_bool](#repair_keyringpkg_bool "")
  * [repair_manualpkg_bool](#repair_manualpkg_bool "")
  * [repair_pikaur01_bool](#repair_pikaur01_bool "")
  * [repair_aurrbld_bool](#repair_aurrbld_bool "")
  * [repair_aurrbldfail_freq](#repair_aurrbldfail_freq "")
  * [self_1enable_bool](#self_1enable_bool "")
  * [self_branch_str](#self_branch_str "")
  * [update_downgrades_bool](#update_downgrades_bool "")
  * [update_mirrors_freq](#update_mirrors_freq "")
  * [update_keys_freq](#update_keys_freq "")
</details>

## Summary

This is a highly configurable, **non-interactive** script for automating updates for Manjaro Linux, with basic support for other distributions based on Arch Linux. It supports updating the following:
* Main system packages (via `pacman`)
* AUR packages (via an [AUR helper](#supported-aur-helpers ""))
* Flatpak packages

Status Notifications are currently supported on the following Desktop Environments:
* Xfce
* KDE (requires [notify-desktop-git](https://aur.archlinux.org/packages/notify-desktop-git) for full notification support)
* Gnome ([permanent notifications extension](https://extensions.gnome.org/extension/41/permanent-notifications/ "") is recommended)
.

## Suggested Usage and Disclaimer:
Please do not use this script blindly. You should have a firm understanding of how to manually update your computer before using this. 
You can learn about updating your computer at the following:
* [Manjaro Wiki](https://wiki.manjaro.org/index.php?title=Main_Page#Software_Management_.2F_Applications)
* [Manjaro User Guide](https://manjaro.org/support/userguide/)
* [Tips for Updating Manjaro](https://forum.manjaro.org/t/root-tip-update-manjaro-the-smart-way/30979)

This is not a replacement for manually updating/maintaining your own computer, but a supplement. This script automates what it can, but updates needing manual steps (for example, merging .pacnew files) will still need those.
Some of the manual steps have been incorporated into this script, but your system(s) may require additional manual steps depending on what packages you have installed.

Always have external bootable media (like a flash drive with manjaro on it) available in case the system becomes unbootable.

## Support of other distributions based on Arch Linux

Functions in this script are designed to be distro-agnostic and should work with any distro that uses pacman. Manjaro Linux continues to be the primary testing environment, but feel free to submit issues/pull requests concerning other distributions.

<details>
<summary>↕VMs tested before each Release (updated from old/original snapshots)↕</summary>

<table>
  <tr><td>Distro</td><td>Desktop</td><td>Arch</td><td>Snapshot Date/Version</td></tr>
  <tr><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/official/xfce">Xfce</a></td><td>x86_64</td><td><code>17.1.7</code> <code>18.0</code> <code>18.1.0</code> <code>2021/06/08</code></tr></tr>
  <tr><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/official/kde">KDE</a></td><td>x86_64</td><td><code>20.0-rc3</code> <code>2020/10/11</code></tr></tr>
  <tr><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/official/gnome">Gnome</a></td><td>x86_64</td><td><code>2021/03/21</code></tr></tr>
  <tr><td><a href="https://archlinux.org">Arch Linux</a></td><td>Xfce</td><td>x86_64</td><td><code>2022/02/04</code></tr></tr>
  <tr><td><a href="https://endeavouros.com">EndeavourOS</a></td><td>Xfce</td><td>x86_64</td><td><code>2021/08/30</code></tr></tr>
  <tr><td><a href="https://garudalinux.org">Garuda Linux</a></td><td>Xfce</td><td>x86_64</td><td><code>2021/08/09</code></tr></tr>
</table>
</details>

<details>
<summary>↕Hardware tested before each Release (continuously updated)↕</summary>

<table>
  <tr><td>Hardware</td><td>Distro</td><td>Desktop</td><td>Arch</td><td>Fresh install version/date</td></tr>
  <tr><td>AMD Ryzen 3500u (thinkpad laptop)</td><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/official/xfce">Xfce</a></td><td>x86_64</td><td><code>2021/11/26</code></tr></tr>
  <tr><td>Intel core i7-3770 + Nvidia gtx 970 (dell tower)</td><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/official/xfce">Xfce</a></td><td>x86_64</td><td><code>2018/10/28</code></tr></tr>
  <tr><td>Pinephone <a href="https://wiki.pine64.org/wiki/PinePhone_v1.2b">v1.2b</a></td><td><a href="https://manjaro.org/">Manjaro Linux</a></td><td><a href="https://manjaro.org/downloads/arm/pinephone/arm8-pinephone-phosh">Phosh</a></td><td>arm</td><td><code>beta 23</code></tr></tr>
</table>
</details>


## Legal stuff
<details>
<summary>↕</summary>

This is licensed under [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
* TL/DR (as I understand it): You can modify, redistribute, or include in sold products as long as you include the license. You lose this right if you start throwing around litigation. No warranty or guarantee is included or implied. **Use at your own risk**.
<details>
<summary>= Expand for License details =</summary>

   Copyright 2016-2023 Steven Hoff (aka "lectrode")

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

</details>

</details>

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
  * Check for and remove `/tmp/pikaur_build_deps.lock`
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

* Pre-update system checks
  * Check if too old (does not support installs with `xproto`<=7.0.31-1)
  * Partial [cache cleanup](#cleanup-tasks "")
  * Check Free space

* Update repo databases
  * `pacman -Syy`
    * Repair upon detection of "error: GPGME error: No data" (*config: [enable](#repair_db02_bool "")*): 
      * delete package database files (normally stored in `/var/lib/pacman/sync`)
      * re-attempt `pacman -Syy`

* Update keyring packages
  * manual update if packages are older than 1.5 years (*config: [enable](#repair_keyringpkg_bool "")*)

* Download package updates
  * `pacman -Su[`[`u`](#update_downgrades_bool "")`]w --needed --noconfirm [--ignore `[`$main_ignorepkgs_str`](#main_ignorepkgs_str "")`]`
    * Upon dependency resolution issues, this will be re-attempted, but with 'd' and 'dd' parameters to skip dependency checks
    * This ensures that as many packages are downloaded as possible before making any major changes

* Apply manual package changes (*config: [enable](#repair_manualpkg_bool "")*)(see [this section](#supported-automatic-repair-and-manual-changes "") for details)
  * If `pacman`<5.2, switch to `pacman-static`
  * Required removal and/or replacement of known conflicting packages

* Update System packages
  * Installed repo packages that end with "-keyring"
  * Installed repo packages that end with "-system"
  * Packages specified in [`$main_systempkgs_str`](#main_systempkgs_str "")

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
  * Check if pikaur is functional (*config: [enable](#repair_pikaur01_bool "")*)

* If AUR helper available/enabled, detect and rebuild AUR packages that need it (*config: [enable](#repair_aurrbld_bool "")*)
  * If packages are still detected as needing a rebuild afterward, these packages are excluded from future attempts (*config: [number of days to exclude](#repair_aurrbldfail_freq "")*)

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
    * mark keyring packages as explicitly installed if they would otherwise be removed
    * `pacman -Rnsc $(pacman -Qtdq) --noconfirm`

  * Package cache cleanup
    * Clean AUR package cache
      * ``paccache -rfqk`[`$cln_aurpkg_num`](#cln_aurpkg_num "") -c /var/cache/apacman/pkg`
      * ``paccache -rfqk`[`$cln_aurpkg_num`](#cln_aurpkg_num "") -c /var/cache/pikaur/pkg`
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
* Remove `flatpak` orphan packages (*config: [enable](#cln_flatpakorphan_bool "")*)
  * `flatpak uninstall --unused -y`
</details>

### Final Actions
<details>
 <summary>↕</summary>

* Stop background notification process
* Determine final message
* Perform System Power Action (i.e. reboot) if required (*config: [enable](#reboot_1enable_num "")*)
  * Delay system power action if users are logged in (*config: [enable](#reboot_delayiflogin_bool ""), [ignore these users](#reboot_ignoreusers_str "")*)
    * Countdown to system power action (*config: [duration](#reboot_delay_num ""), [notification frequency](#reboot_notifyrep_num "")*)
  * `sync; [reboot|halt|poweroff] || systemctl --force [reboot|halt|poweroff] || systemctl --force --force [reboot|halt|poweroff]` (*config: [action](#reboot_action_str "")*)
* Final message if system power action not performed (*config: [duration](#notify_lastmsg_num "")*)
* Stop auto-update service and quit
</details>

----

</details>

## Supported Automatic Repair and Manual Changes
<details>
<summary>↕</summary>

 
Note: All current and future automatic repair and manual package changes can be [disabled in one setting](#repair_1enable_bool "")

### Automatic Repair
This script supports detecting and repairing the following potential issues:
* Package database errors [error 1](#repair_db01_bool "") | [error 2](#repair_db02_bool "")
* [Obsolete keyring packages](#repair_keyringpkg_bool "")
* [Non-functioning Pikaur](#repair_pikaur01_bool "")
* [AUR packages requiring rebuild after dependency update](#repair_aurrbld_bool "")


### Manual Package Changes
Every once in a while, updating Manjaro requires manual package changes to allow updates to succeed. This script [supports](#repair_manualpkg_bool "") automatically performing the following:
* Setup and use `pacman-static` if `pacman`<5.2
* Transition packages that depend on `electron` to `electronXX` where required
* Package removal and/or replacement:
<table>
  <tr><td><code>wxgtk2</code></td><td><=3.0.5.1-3</td><td>2022/07/14: removed from arch repos</td></tr>
  <tr><td><code>pipewire-media-session</code></td><td><=1:0.4.1-1</td><td>2022/05/10: replaced with <code>wireplumber</code></td></tr>
  <tr><td><code>qpdfview</code></td><td><=0.4.18-1</td><td>2022/04/01: former default pkg moved to AUR, replaced with <code>evince</code></td></tr>
  <tr><td><code>galculator-gtk2</code></td><td><=2.1.4-5</td><td>2021/11/13: replaced with <code>galculator</code></td></tr>
  <tr><td><code>manjaro-gdm-theme</code></td><td><=20210528-1</td><td>2022/04/23: removed from repos</td></tr>
  <tr><td><code>manjaro-kde-settings-19.0</code>,<code>breath2-icon-themes</code>,<code>plasma5-themes-breath2</code></td><td><=20200426-1</td><td>2021/11: replaced with <code>plasma5-themes-breath</code>,<code>manjaro-kde-settings</code></td></tr>
  <tr><td><code>[lib32-]jack</code></td><td><=0.125.0-10</td><td>2021/07/26: replaced with <code>lib32-/jack2</code></td></tr>
  <tr><td><code>[lib32-]libcanberra-gstreamer</code></td><td><=0.30+2+gc0620e4-3</td><td>2021/06: merged into <code>lib32-/libcanberra-pulse</code></td></tr>
  <tr><td><code>python2-dbus</code></td><td><=1.2.16-3</td><td>2021/03: removed from <code>dbus-python</code></td></tr>
  <tr><td><code>knetattach</code></td><td><=5.20.5-1</td><td>2021/01/09: merged into <code>plasma-desktop</code></td></tr>
  <tr><td><code>gksu-polkit</code></td><td><=0.0.3-2</td><td>2020/10: replaced with <code>zensu</code></td></tr>
  <tr><td><code>ms-office-online</code></td><td><=20.1.0-1</td><td>2020/06: former default pkg moved to AUR</td></tr>
  <tr><td><code>pyqt5-common</code></td><td><=5.13.2-1</td><td>2019/12: removed from repos</td></tr>
  <tr><td><code>ilmbase</code></td><td><=2.3.0-1</td><td>2019/10: merged into <code>openexr</code></td></tr>
  <tr><td><code>breeze-kde4</code></td><td><=5.13.4-1</td><td>2019/05: removed from repos</td></tr>
  <tr><td><code>oxygen-kde4</code></td><td><=5.13.4-1</td><td>2019/05: removed from repos</td></tr>
  <tr><td><code>sni-qt</code></td><td><=0.2.6-5</td><td>2019/05: removed from repos</td></tr>
  <tr><td><code>colord</code></td><td><=1.4.4-1</td><td>2019/??: conflicts with <code>libcolord</code></td></tr>
  <tr><td><code>[lib32-]gtk3-classic</code></td><td><=3.24.24-1</td><td>Xfce 18.0.4: replaced with <code>gtk3</code></td></tr>
  <tr><td><code>engrampa-thunar-plugin</code></td><td><=1.0-2</td><td>Xfce 17.1.10: removed from repos</td></tr>
</table>

* Mark packages as explicitely installed:

<table>
  <tr><td><code>adapta-black-breath-theme</code><br />
          <code>adapta-black-maia-theme</code><br />
          <code>adapta-breath-theme</code><br />
          <code>adapta-gtk-theme</code><br />
          <code>adapta-maia-theme</code><br />
          <code>arc-themes-maia</code><br />
          <code>arc-themes-breath</code><br />
          <code>matcha-gtk-theme</code></td><td>mistakenly marked as orphans after <code>kvantum-manjaro</code>>0.13.5-1</td></tr>
</table>

* Mark packages as dependency:

<table>
  <tr><td><code>phonon-qt4-gstreamer</code><br />
          <code>phonon-qt4-vlc</code><br />
          <code>phonon-qt4-mplayer-git</code></td><td>extras for phonon-qt4<=4.10.3-1 (moved to AUR 2019/05)</td></tr>
</table>

----

</details>

## Installation and Requirements
<details>
<summary>↕</summary>

### Dependencies:

Required:
 * `coreutils`, `pacman`, `grep`, `iputils`

Optional:
<table>
  <tr><td><code>pacman-contrib</code></td><td>for package cache cleanup support (if packaged separately, i.e. Arch Linux)</td></tr>
  <tr><td><code>pacman-mirrors</code></td><td>for mirror update support</td></tr>
  <tr><td><a href="#supported-aur-helpers">AUR Helper</a></td><td>for AUR package support</td></tr>
  <tr><td><code>flatpak</code></td><td>for flatpak package support</td></tr>
  <tr><td>notification daemon</td><td>usually a part of the desktop environment; for notification support</td></tr>
  <tr><td><code>lsof</code></td><td>for more thorough detection of reboot needed on login</td></tr>
  <tr><td><a href="https://aur.archlinux.org/packages/notify-desktop-git"><code>notify-desktop</code></a></td><td>required for KDE notifications, optional alternative for Xfce, Gnome</td></tr>
  <tr><td><code>wget</code></td><td>if available, will use instead of <code>curl</code></td></tr>
</table>

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

4) You can manually run the script with the following:
  * `sudo systemctl start xs-autoupdate` (run silently as service)
  * `sudo /usr/share/xs/auto-update.sh` (watch logs)
  * `sudo /usr/share/xs/auto-update.sh nofork` (watch logs, do not fork to background)

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
cln_aurpkg_num=1
cln_flatpakorphan_bool=1
cln_orphan_bool=1
cln_paccache_num=1
flatpak_update_freq=3
main_country_str=Global,United_States
main_ignorepkgs_str=
main_logdir_str=/var/log/xs
main_perstdir_str=
main_systempkgs_str=
main_testsite_str=www.google.com
notify_1enable_bool=1
notify_errors_bool=1
notify_function_str=auto
notify_lastmsg_num=20
notify_vsn_bool=0
reboot_1enable_num=1
reboot_action_str=reboot
reboot_delayiflogin_bool=1
reboot_delay_num=120
reboot_ignoreusers_str=nobody lightdm sddm gdm
reboot_notifyrep_num=10
repair_db01_bool=1
repair_db02_bool=1
repair_manualpkg_bool=1
repair_pikaur01_bool=1
repair_aurrbld_bool=1
repair_aurrbldfail_freq=32
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
<summary><a name="cln_aurpkg_num"></a>cln_aurpkg_num</summary>

* Default: `1`
* Specifies the number of AUR (built) package versions to keep in cache
* If set to "-1" all AUR package versions will be kept
* pikaur cache:  `/var/cache/pikaur/pkg`
* apacman cache: `/var/cache/apacman/pkg`
</details>

<details>
<summary><a name="cln_aurbuild_bool"></a>cln_aurbuild_bool</summary>

* Default: `1` (True)
* If this is True, all AUR package build folders will be deleted when finished
</details>

<details>
<summary><a name="cln_orphan_bool"></a>cln_orphan_bool</summary>

* Default: `1` (True)
* If this is True, obsolete dependencies from main repos will be uninstalled
</details>

<details>
<summary><a name="cln_flatpakorphan_bool"></a>cln_flatpakorphan_bool</summary>

* Default: `1` (True)
* If this is True, obsolete flatpak dependencies will be uninstalled
</details>

<details>
<summary><a name="cln_paccache_num"></a>cln_paccache_num</summary>

* Default: `1`
* Specifies the number of repo package versions to keep in cache
* If set to "-1" all official package versions will be kept (cache is usually `/var/cache/pacman/pkg`)
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
* Packages to ignore, separated by spaces (these are in addition to those stored in pacman.conf)
</details>

<details>
<summary><a name="main_systempkgs_str"></a>main_systempkgs_str</summary>

* Default: (blank)
* Packages to update before any other packages (i.e. `archlinux-keyring`), separated by spaces
</details>

<details>
<summary><a name="main_inhibit_bool"></a>main_inhibit_bool</summary>

* Default: `1` (True)
* If true, script will inhibit accidental restart/shutdown/hibernate/suspend while the script is updating the system
* This can be manually overridden with one of the following methods:
  * WARNING: interupting a system update can result in a non-functoinal system! Use with caution!
  * Execute with elevated permissions, i.e. `sudo reboot`, or `sudo systemctl suspend`
  * Stop the script with `sudo pkill auto-update`
* NOTE: On KDE, while inhibited, selecting shutdown or restart results in a black screen (use different TTY to get back in)
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

 * Determines when script should perform "System Power Action" (see `reboot_action_str` below)
 * Default: `1`
 * -1: Disable in all cases
 *  0: Only if rebooting manually may not be possible (system may be in critical state after critical package update)
 *  1: Only after critical system packages have been updated
 *  2: Always reboot, regardless of any updates
</details>

<details>
<summary><a name="reboot_action_str"></a>reboot_action_str</summary>

 * This is the System Power Action the script should take when required
 * Default: `reboot`
 * `reboot`: System will be restarted
 * `halt`: System will be halted (shutdown, with hardware left running)
 * `poweroff`: System will be powered off (shutdown, with hardware powered off)
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
<summary><a name="repair_1enable_bool"></a>repair_1enable_bool</summary>

 * Default: `1` (True)
 * Enables/Disables all repair steps
 * NOTE: If either this, or the individual repair option is disabled, that repair will be ignored

</details>

<details>
<summary><a name="repair_db01_bool"></a>repair_db01_bool</summary>

 * Default: `1` (True)
 * If true, the script will detect and attempt to repair missing "desc"/"files" files in package database
 * NOTE: It repairs this by creating the missing files and re-installing the package(s) with `overwrite=*` specified

</details>

<details>
<summary><a name="repair_db02_bool"></a>repair_db02_bool</summary>

 * Default: `1` (True)
 * If true, the script will detect and attempt to redownload corrupt package database files
 * NOTE: It repairs this by removing existing package database files, then running 'pacman -Syy'

</details>

<details>
<summary><a name="repair_keyringpkg_bool"></a>repair_keyringpkg_bool</summary>

 * Default: `1` (True)
 * If true, the script will detect and attempt to repair outdated keyring packages

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
<summary><a name="repair_aurrbld_bool"></a>repair_aurrbld_bool</summary>

 * Default: `1` (True)
 * If true, the script will attempt to rebuild AUR python packages after python update
 * Depends on external tool: rebuild-detector (available in official repos)
</details>

<details>
<summary><a name="repair_aurrbldfail_freq"></a>repair_aurrbldfail_freq</summary>

 * Default: `32` (True)
 * After the script finishes attempting to rebuild packages that need it, any packages that still need to be rebuilt are excluded from future runs for this number of days
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



