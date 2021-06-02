#!/bin/bash
#Auto Update For Manjaro by Lectrode
vsn="v3.7.2-rc1"; vsndsp="$vsn 2021-06-02"
#-Downloads and Installs new updates
#-Depends: coreutils, grep, pacman, pacman-mirrors, iputils
#-Optional Depends: flatpak, notify-desktop, pikaur, rebuild-detector, wget

#   Copyright 2016-2021 Steven Hoff (aka "lectrode")

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

true=0; false=1; ctrue=1; cfalse=0
if [ $# -eq 0 ]; then "$0" "XS"& exit 0; fi # fork to background (start with "nofork" parameter to avoid this)
[[ "$xs_autoupdate_conf" = "" ]] && xs_autoupdate_conf='/etc/xs/auto-update.conf'
[[ "$DEFAULTIFS" = "" ]] && DEFAULTIFS="$IFS"
debgn=+x; # -x =debugging | +x =no debugging
set $debgn; pcmbin="pacman"
device="device"; [[ "$(uname -m)" = "x86_64" ]] && device="computer"

#---Define Functions---

cnvrt2_int(){ if ! [[ "$1" =~ ^[\-]?[0-9]+$ ]]; then echo 0; return; fi; echo $1; }

trouble(){ (echo;echo "#XS# $(date) - $@") |tee -a $log_f; }
troublem(){ echo "XS-$@" |tee -a $log_f; }

troubleqin(){ logqueue+=("#XS# $(date) - $@"); }
troubleqout(){
    while [ 0 -lt ${#logqueue[@]} ]; do
        (echo;echo "${logqueue[0]}") |tee -a $log_f
        logqueue=(${logqueue[@]:1})
    done
}

test_online(){ ping -c 1 "${conf_a[main_testsite_str]}" >/dev/null 2>&1 && return 0; return 1; }

pacclean(){
[[ ! "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] && return

[[ "$(expr ${conf_a[cln_aurpkg_bool]} + ${conf_a[cln_aurbuild_bool]} + ${conf_a[cln_paccache_num]})" -gt "-1" ]] && trouble "Performing cleanup operations..."

if [[ "${conf_a[cln_aurpkg_bool]}" = "$ctrue" ]]; then
    troublem "Cleaning AUR package cache..."
    if [ -d /var/cache/apacman/pkg ]; then rm -rf /var/cache/apacman/pkg/*; fi
    if [ -d /var/cache/pikaur/pkg ]; then rm -rf /var/cache/pikaur/pkg/*; fi
fi

if [[ "${conf_a[cln_aurbuild_bool]}" = "$ctrue" ]]; then
    troublem "Cleaning AUR build cache..."
    if [ -d /var/cache/pikaur/aur_repos ]; then rm -rf /var/cache/pikaur/aur_repos/*; fi
    if [ -d /var/cache/pikaur/build ]; then rm -rf /var/cache/pikaur/build/*; fi
fi

if [[ "${conf_a[cln_paccache_num]}" -gt "-1" ]]; then
    troublem "Cleaning pacman cache..."
    paccache -rfqk${conf_a[cln_paccache_num]}
fi
}

chk_pkgisinst(){ if [[ "$($pcmbin -Qq $1 2>/dev/null | grep -m1 -x $1)" == "$1" ]]; then [[ "$2" = "1" ]] && echo "$1"; return 0; else return 1; fi }
get_pkgvsn(){ echo "$($pcmbin -Q $1 | grep "$1 " -m1 | cut -d' ' -f2)"; }
chk_pkgvsndiff(){ cpvd_t1="$(get_pkgvsn $1)"; echo "$(vercmp ${cpvd_t1:-0} $2)"; unset cpvd_t1; }

chk_sha256(){ [[ "$(sha256sum "$1" |cut -d ' ' -f 1 |tr -cd [:alnum:])" = "$2" ]] && return 0; return 1; }

dl_outstd(){
#$1=url
if wget --help >/dev/null 2>&1; then
    wget -qO- "$1" && return 0; fi
curl -s "$1" && return 0; return 1
}
dl_outfile(){
#$1=url $2=output dir
if [[ ! -d "$2" ]]; then mkdir "$2" || return 1; fi
if wget --help >/dev/null 2>&1; then
    wget -q "$1" -O "$2/$(basename "$1")" && return 0; fi
curl -sZL "$1" -o "$(basename "$1")" --output-dir "$2" && return  0; return 1
}
dl_clean(){ [[ -d "/tmp/xs-autmp-$1" ]] && rm -rf "/tmp/xs-autmp-$1"; }
dl_verify(){
#$1=id; $2=remote hash; $3=remote file
dl_hash="$(dl_outstd "$2" |tr -cd [:alnum:])"
if [ "${#dl_hash}" = "64" ]; then
    (dl_outfile "$3" "/tmp/xs-autmp-$1/") 2>&1 |tee -a $log_f
    chk_sha256 "/tmp/xs-autmp-$1/$(basename $3)" "$dl_hash" && return 0
fi; dl_clean $1; return 1
}

get_pkgfilename(){
#$1=pkg name
regex="^$1-([0-9\.+:a-z]+-[0-9\.]+)-[0-9a-z_]+.pkg.[0-9a-z]+.[0-9a-z]+$"
i=-1; while IFS= read -r gpfn_t1; do
    if [[ "$gpfn_t1" =~ $regex ]]; then
        gpfn_t3="$($pcmbin -Q $1 | grep "$1 " -m1 | cut -d' ' -f2)"
        if [[ "$(vercmp ${BASH_REMATCH[1]} ${gpfn_t3:-0})" -ge 0 ]]; then
            gpfn_t2+=("$(get_pacmancfg CacheDir)$gpfn_t1"); break; fi
    fi
done< <(ls "$(get_pacmancfg CacheDir)"|grep -E "^$1-[0-9]"|sort -r)
echo "$gpfn_t2"; unset gpfn_t1 gpfn_t2 gpfn_t3 i regex
}

get_pacmancfg(){
#$1=prop
if pacman-conf --help >/dev/null 2>&1; then pacman-conf $1; return; fi
if [[ -f /etc/pacman.conf ]]; then
    gpcc="$(grep -E "^[^#]?$1" /etc/pacman.conf |sed -r 's/ += +/=/g'|cut -d'=' -f2)"
    if [[ ! "$gpcc" = "" ]]; then echo "$gpcc/"|sed -r 's_/+_/_g'; unset gpcc; return; fi; unset gpcc; fi
if [[ "$1" = "DBPath" ]]; then echo "/var/lib/pacman/"; fi
if [[ "$1" = "CacheDir" ]]; then echo "/var/cache/pacman/pkg/"; fi
}

chk_crit(){
if grep -Ei "(up|down)(grad|dat)ing (linux([0-9]{2,3}|-pinephone)|systemd|mesa|(intel|amd)-ucode|cryptsetup|xf86-video)(\.|-| )" $log_f >/dev/null;
then echo crit; else echo norm; fi
}

conf_export(){
if [ ! -d "$(dirname $xs_autoupdate_conf)" ]; then mkdir "$(dirname $xs_autoupdate_conf)"; fi
echo '#Config for XS-AutoUpdate' > "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# AUR Settings #' >> "$xs_autoupdate_conf"
echo '#aur_1helper_str:          Valid options are auto,none,all,pikaur,apacman' >> "$xs_autoupdate_conf"
echo '#aur_aftercritical_bool:   Enable/Disable AUR updates immediately after critical system updates' >> "$xs_autoupdate_conf"
echo '#aur_update_freq:          Update AUR packages every X days' >> "$xs_autoupdate_conf"
echo '#aur_devel_freq:           Update -git and -svn AUR packages every X days (-1 to disable, best if a multiple of aur_update_freq, pikaur only)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Cleanup Settings #' >> "$xs_autoupdate_conf"
echo '#cln_1enable_bool:         Enable/Disable ALL package cleanup (overrides following cleanup settings)' >> "$xs_autoupdate_conf"
echo '#cln_aurpkg_bool:          Enable/Disable AUR package cleanup' >> "$xs_autoupdate_conf"
echo '#cln_aurbuild_bool:        Enable/Disable AUR build cleanup' >> "$xs_autoupdate_conf"
echo '#cln_flatpakorphan_bool:   Enable/Disable uninstall of uneeded flatpak packages' >> "$xs_autoupdate_conf"
echo '#cln_orphan_bool:          Enable/Disable uninstall of uneeded repo packages' >> "$xs_autoupdate_conf"
echo '#cln_paccache_num:         Number of official packages to keep (-1 to keep all)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Flatpak Settings #' >> "$xs_autoupdate_conf"
echo '#flatpak_update_freq:      Check for Flatpak package updates every X days (-1 to disable)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Notification Settings #' >> "$xs_autoupdate_conf"
echo '#notify_1enable_bool:      Enable/Disable nofications' >> "$xs_autoupdate_conf"
echo '#notify_function_str:      Valid options are auto,gdbus,desk,send' >> "$xs_autoupdate_conf"
echo '#notify_lastmsg_num:       Seconds before final normal notification expires (0=never)' >> "$xs_autoupdate_conf"
echo '#notify_errors_bool:       Include failed tasks in summary notification' >> "$xs_autoupdate_conf"
echo '#notify_vsn_bool:          Include version number in notifications' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Main Settings #' >> "$xs_autoupdate_conf"
echo '#main_ignorepkgs_str:      List of packages to ignore separated by spaces (in addition to pacman.conf)' >> "$xs_autoupdate_conf"
echo '#main_systempkgs_str:      List of packages to update before any other packages (i.e. archlinux-keyring)' >> "$xs_autoupdate_conf"
echo '#main_logdir_str:          Path to the log directory' >> "$xs_autoupdate_conf"
echo '#main_perstdir_str:        Path to the persistant timestamp directory (uses main_logdir_str if not defined)' >> "$xs_autoupdate_conf"
echo '#main_country_str:         Countries separated by commas from which to pull updates. Default is automatic (geoip)' >> "$xs_autoupdate_conf"
echo '#main_testsite_str:        URL (without protocol) used to test internet connection' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Reboot Settings #' >> "$xs_autoupdate_conf"
echo '#reboot_1enable_num:       Perform system power action: 2=always, 1=only after critical updates, 0=only if normal reboot may not be possible, -1=never' >> "$xs_autoupdate_conf"
echo '#reboot_action_str:        System power action. Valid options are reboot, halt, poweroff' >> "$xs_autoupdate_conf"
echo "#reboot_delayiflogin_bool: Only delay rebooting $device if users are logged in" >> "$xs_autoupdate_conf"
echo "#reboot_delay_num:         Delay in seconds to wait before rebooting the $device" >> "$xs_autoupdate_conf"
echo '#reboot_notifyrep_num:     Reboot notification is updated every X seconds. Best if reboot_delay_num is evenly divisible by this' >> "$xs_autoupdate_conf"
echo '#reboot_ignoreusers_str:   Ignore these users even if logged on. List users separated by spaces' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Automatic Repair Settings #' >> "$xs_autoupdate_conf"
echo '#repair_db01_bool:         Enable/Disable Repair missing "desc"/"files" files in package database' >> "$xs_autoupdate_conf"
echo '#repair_manualpkg_bool:    Enable/Disable Perform critical package changes required for continued updates' >> "$xs_autoupdate_conf"
echo '#repair_pikaur01_bool:     Enable/Disable Re-install pikaur if not functioning' >> "$xs_autoupdate_conf"
echo '#repair_aurrbld_bool:      Enable/Disable Rebuild AUR packages after dependency updates (requires AUR helper enabled)' >> "$xs_autoupdate_conf"
echo '#repair_aurrbldfail_freq:  Retry rebuild/reinstall of AUR packages after dependency updates every X days (-1=never, 0=always)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Self-update Settings #' >> "$xs_autoupdate_conf"
echo '#self_1enable_bool:        Enable/Disable updating self (this script)' >> "$xs_autoupdate_conf"
echo '#self_branch_str:          Update branch (this script only): stable, beta' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Update Settings #' >> "$xs_autoupdate_conf"
echo '#update_downgrades_bool:   Directs pacman to downgrade package if remote is older than local' >> "$xs_autoupdate_conf"
echo '#update_mirrors_freq:      Update mirror list every X days (-1 to disable)' >> "$xs_autoupdate_conf"
echo '#update_keys_freq:         Check for security signature/key updates every X days (-1 to disable)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Custom Makepkg Flags for AUR packages (requires pikaur)' >> "$xs_autoupdate_conf"
echo '#zflag:packagename1,packagename2=--flag1,--flag2,--flag3' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
IFS=$'\n'; for i in $(sort <<< "${!conf_a[*]}"); do
	echo "$i=${conf_a[$i]}" >> "$xs_autoupdate_conf"
done; IFS=$DEFAULTIFS
}

#Persistant Data Functions

perst_isneeded(){
#$1 = frequency: xxxx_freq
#$2 = previous date: perst_a[last_xxxx]

    if [[ "$1" -eq "-1" ]]; then return 1; fi
    curdate=$(date +'%Y%m%d')
    scheddate=$(date -d "$2 + $1 days" +'%Y%m%d')
    
    if [[ "$scheddate" -le "$curdate" ]]; then
        return 0
    elif [[ "$2" -gt "$curdate" ]]; then
        return 0
    else
        return 1
    fi
}

perst_update(){
#$1 = last_*
    perst_a[$1]=$(date +'%Y%m%d'); echo "$1=$(date +'%Y%m%d')" >> "$perst_f"
    echo "$1" | grep -F "zrbld:" >/dev/null && \
        rbld_a["$(echo "$1" | cut -d ':' -f 2)"]=$(date +'%Y%m%d')
}

perst_export(){
    touch "$perst_f"
    echo "#Last day specific tasks were performed" > "$perst_f"
    IFS=$'\n'; for i in $(sort <<< "${!perst_a[*]}"); do
        echo "$i=${perst_a[$i]}" >> "$perst_f"
    done; IFS=$DEFAULTIFS
}

perst_reset(){
#$1 = last_*
    if echo "$1" | grep -F "zrbld:" >/dev/null; then
        unset rbld_a["$(echo "$1" | cut -d ':' -f 2)"] perst_a[$1]
        perst_export #cannot use sed, as anything between [] is treated as regex
    else perst_a[$1]="20010101"; echo "$1=20010101" >> "$perst_f"; fi
}

aurrebuildlist(){
    arlist="$(checkrebuild|grep -oP '^foreign[[:space:]]+\K(?!.*-bin$)([[:alnum:]\.@_\+\-]*)$' 2>/dev/null)"

    #remove stale rebuild cache entries
    arlist_grep="$(echo -n "$arlist"|tr '\n' '|')"
    for pkg in ${!rbld_a[*]}; do
        if [[ "$arlist" = "" ]]; then perst_reset "zrbld:$pkg"; continue; fi
        if ! echo "$pkg"|grep -E "^($arlist_grep)$" >/dev/null; then perst_reset "zrbld:$pkg"; fi
    done

    #return active list
    arignore="$(echo "${!rbld_a[*]}"|sed 's/ /\\|/g')"
    if [[ "$arignore" = "" ]]; then echo "$arlist"|tr '\n' ' '
    else echo "$arlist"|grep -v "$arignore"|tr '\n' ' '; fi

    unset arlist arignore arlist_grep
}


#Notification Functions

iconnormal(){ icon=ElectrodeXS; }
iconwarn(){ icon=important; }
iconcritical(){ icon=system-shutdown; }

sendmsg(){
#$1=user; $2=msg; [$3=timeout]
    if [[ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]] && [[ "$(($noti_desk+$noti_send+$noti_gdbus))" -le 2 ]]; then
        noti_id["$1"]="$(cnvrt2_int "${noti_id["$1"]}")"
        tmp_t0="$(cnvrt2_int "$3")"
        if [ "$tmp_t0" = "0" ]; then
            tmp_t1="-u critical"
        else
            let tmp_t0="$tmp_t0*1000"
            tmp_t1="-t $tmp_t0"
        fi
        if [ "$noti_desk" = "$true" ]; then
            if [[ "$2" = "dismiss" ]]; then
                noti_id["$1"]="$(su $1 -c "notify-desktop -u normal -r ${noti_id["$1"]} \" \" -t 1")"
            else
                tmp_m1="$(echo "$2"|sed 's/\\n/\n/g')"
                noti_id["$1"]="$(su $1 -c "notify-desktop -i $icon $tmp_t1 -r ${noti_id["$1"]} xs-update-manjaro \"$notifyvsn$tmp_m1\" 2>/dev/null || echo error")"
            fi
        fi
        if [ "$noti_send" = "$true" ]; then
            if [[ ! "$2" = "dismiss" ]]; then
                noti_id["$1"]="$(su $1 -c "notify-send -i $icon $tmp_t1 xs-update-manjaro \"$notifyvsn$2\" 2>/dev/null || echo error")"
            fi
        fi
        if [ "$noti_gdbus" = "$true" ]; then
            if [[ "$2" = "dismiss" ]]; then
                noti_id["$1"]="$(su $1 -c "gdbus call --session --dest org.freedesktop.Notifications \
                    --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification ${noti_id["$1"]}")"
            else
                noti_id["$1"]="$(su $1 -c "gdbus call --session --dest org.freedesktop.Notifications \
                    --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify \
                    xs-update-manjaro ${noti_id["$1"]} $icon xs-update-manjaro \"$notifyvsn$2\" [] {} $tmp_t0 2>/dev/null || echo error"|cut -d' ' -f2|cut -d',' -f1)"
            fi
        fi
        unset tmp_t0 tmp_t1; if [[ "${noti_id["$1"]}" = "error" ]]; then noti_id["$1"]=0; return 1; fi
    else systemctl is-system-running 2>/dev/null |grep 'unknown' >/dev/null && return 1
    fi; return 0
}

getsessions(){
    IFS=$'\n\b'; unset s_usr[@] s_disp[@] s_home[@]
    i=0; for sssn in $(loginctl list-sessions --no-legend); do
        IFS=' '; sssnarr=($sssn)
        actv="$(loginctl show-session -p Active ${sssnarr[0]}|cut -d'=' -f2)"
        [[ "$actv" = "yes" ]] || continue
        usr="$(loginctl show-session -p Name ${sssnarr[0]}|cut -d'=' -f2)"
        disp="$(loginctl show-session -p Display ${sssnarr[0]}|cut -d'=' -f2)"
        [[ "$disp" = "" ]] && disp=":0" #workaround for gnome, which returns nothing
        usrhome="$(getent passwd "$usr"|cut -d: -f6)"
        [[  ${usr-x} && ${disp-x} && ${usrhome-x} ]] || continue
        s_usr[$i]=$usr; s_disp[$i]=$disp; s_home[$i]=$usrhome; i=$(($i+1)); IFS=$'\n\b';
    done
    if [ ${#s_usr[@]} -eq 0 ]; then sleep 5; fi
    IFS=$DEFAULTIFS; unset i usr disp usrhome actv sssnarr sssn
}

sendall(){
    if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then
        sa_err=0; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
            DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${s_usr[$i]})/bus" \
                sendmsg "${s_usr[$i]}" "$1" "$2" || sa_err=1
            i=$(($i+1))
        done; unset i; return $sa_err
    fi
}

backgroundnotify(){
iconwarn; while : ; do
    sleep 5
    if [[ -f "${perst_d}\auto-update_termnotify.dat" ]]; then 
        rm -f "${perst_d}\auto-update_termnotify.dat" >/dev/null 2>&1; sendall "dismiss"; exit 0; fi
    getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
        if [ -f "${s_home[$i]}/.cache/xs/logonnotify" ]; then
            DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${s_usr[$i]})/bus" \
                sendmsg "${s_usr[$i]}" "System is updating (please do not turn off the $device)\nDetails: $log_f"
            rm -f "${s_home[$i]}/.cache/xs/logonnotify"
        fi; i=$(($i+1))
    done
done; }

userlogon(){
    #This uses notify-send directly as it is run directly in user session for final message only
    sleep 5; if [ ! -d "$HOME/.cache/xs" ]; then mkdir -p "$HOME/.cache/xs"; fi
    if [ ! -f "${conf_a[main_logdir_str]}/auto-update.log" ]; then
    if [[ $(ls "${conf_a[main_logdir_str]}" | grep -F "auto-update.log_" 2>/dev/null) ]]; then
        iconcritical; notify-send -i $icon XS-AutoUpdate -u critical \
            "Kernel and/or drivers were updated. Please restart your $device to finish"
    fi; else touch "$HOME/.cache/xs/logonnotify"; fi
}

exit_passive(){
    trouble "XS-done"; sync; disown -a; sleep 1
    systemctl stop xs-autoupdate.service >/dev/null 2>&1; exit 0
}

exit_active(){
#$1 = reason
    secremain=${conf_a[reboot_delay_num]}
    actn_cmd="${conf_a[reboot_action_str]}"
    ignoreusers="$(echo "${conf_a[reboot_ignoreusers_str]}" |sed 's/ /\\\|/g')"
    iconcritical; trouble "Active Exit: $actn_cmd";trouble "XS-done"
    while [ $secremain -gt 0 ]; do
        usersexist=$false; loginctl list-sessions --no-legend |grep -v "$ignoreusers" |grep "seat\|pts" >/dev/null && usersexist=$true

        if [ "${conf_a[reboot_delayiflogin_bool]}" = "$ctrue" ]; then
            if [ "$usersexist" = "$false" ]; then troublem "No logged-in users detected; System will $actn_cmd now"; secremain=0; sleep 1; continue; fi; fi

        if [[ "$usersexist" = "$true" ]]; then sendall "$1\nYour $device will $actn_cmd in \n$secremain seconds..."; fi
        sleep ${conf_a[reboot_notifyrep_num]}
        let secremain-=${conf_a[reboot_notifyrep_num]}
    done
    sync; $actn_cmd || systemctl --force $actn_cmd || systemctl --force --force $actn_cmd
}


#---Init Config---

#Init Defaults

typeset -A flag_a

typeset -A conf_a; conf_a=(
    [aur_1helper_str]="auto"
    [aur_aftercritical_bool]=$cfalse
    [aur_update_freq]=3
    [aur_devel_freq]=6
    [cln_1enable_bool]=$ctrue
    [cln_aurpkg_bool]=$ctrue
    [cln_aurbuild_bool]=$ctrue
    [cln_flatpakorphan_bool]=$ctrue
    [cln_orphan_bool]=$ctrue
    [cln_paccache_num]=1
    [flatpak_update_freq]=3
    [notify_1enable_bool]=$ctrue
    [notify_function_str]="auto"
    [notify_lastmsg_num]=20
    [notify_errors_bool]=$ctrue
    [notify_vsn_bool]=$cfalse
    [main_ignorepkgs_str]=""
    [main_systempkgs_str]=""
    [main_logdir_str]="/var/log/xs"
    [main_perstdir_str]=""
    [main_country_str]=""
    [main_testsite_str]="www.google.com"
    [self_1enable_bool]=$ctrue
    [self_branch_str]="stable"
    [update_downgrades_bool]=$ctrue
    [update_keys_freq]=30
    [update_mirrors_freq]=1
    [reboot_1enable_num]=1
    [reboot_action_str]="reboot"
    [reboot_delayiflogin_bool]=$ctrue
    [reboot_delay_num]=120
    [reboot_notifyrep_num]=10
    [reboot_ignoreusers_str]="nobody lightdm sddm gdm"
    [repair_db01_bool]=$ctrue
    [repair_manualpkg_bool]=$ctrue
    [repair_pikaur01_bool]=$ctrue
    [repair_aurrbld_bool]=$ctrue
    [repair_aurrbldfail_freq]=32
    #legacy
    [bool_detectErrors]=""
    [bool_Downgrades]=""
    [bool_notifyMe]=""
    [bool_updateFlatpak]=""
    [bool_updateKeys]=""
    [str_cleanLevel]=""
    [str_ignorePackages]=""
    [str_log_d]=""
    [str_mirrorCountry]=""
    [str_testSite]=""
    [aur_devel_bool]=""
    [flatpak_1enable_bool]=""
    [reboot_1enable_bool]=""
)

validconf=$(echo "${!conf_a[*]}"|sed 's/ /\\|/g')

conf_int0="notify_lastmsg_num reboot_delay_num reboot_notifyrep_num"
conf_intn1="cln_paccache_num aur_update_freq aur_devel_freq flatpak_update_freq update_keys_freq \
    update_mirrors_freq reboot_1enable_num"
conf_legacy="bool_detectErrors bool_Downgrades bool_notifyMe bool_updateFlatpak bool_updateKeys str_cleanLevel \
    str_ignorePackages str_log_d str_mirrorCountry str_testSite aur_devel_bool flatpak_1enable_bool \
    reboot_1enable_bool repair_pythonrebuild_bool"

#Load external config
#Basic config validation

if [[ -f "$xs_autoupdate_conf" ]]; then
    while read line; do
        line="$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)"
        if echo "$line" | grep -F '=' &>/dev/null; then
            varname="$(echo "$line" | cut -d '=' -f 1)"
            if ! echo $varname |grep "$validconf" >/dev/null; then
                echo "$varname"|grep -F "zflag:" >/dev/null || continue
            fi
            line="$(echo "$line" | cut -d '=' -f 2-)"
            if [[ ! "$line" = "" ]]; then
                #validate boolean
                echo "$varname" | grep -F "bool" >/dev/null && if [[ ! ( "$line" = "$ctrue" || \
                    "$line" = "$cfalse" ) ]]; then continue; fi
                #validate numbers
                if echo "$varname" | grep "num" >/dev/null; then 
                    if [[ ! "$line" = "0" ]]; then line="$(cnvrt2_int "$line")"
                    [[ "$line" = "0" ]] && continue; fi; fi
                #validate integers 0+
                if echo "$conf_int0" | grep "$varname" >/dev/null; then 
                    if [[ "$line" -lt "0" ]]; then continue; fi; fi
                #validate integers -1+
                if echo "$conf_intn1" | grep "$varname" >/dev/null; then 
                    if [[ "$line" -lt "-1" ]]; then continue; fi; fi
                #validate reboot_action_str
                if [[ "$varname" = "reboot_action_str" ]]; then case "$line" in
                        reboot|halt|poweroff) ;;
                        shutdown) line="poweroff" ;;
                        *) continue
                esac; fi
                #validate reboot_notifyrep_num
                if [[ "$varname" = "reboot_notifyrep_num" ]]; then
                    if [[ "$line" -gt "${conf_a[reboot_delay_num]}" ]]; then
                        line=${conf_a[reboot_delay_num]}; fi
                    if [[ "$line" = "0" ]]; then
                        line=1; fi
                fi
                #validate aur_1helper_str
                if [[ "$varname" = "aur_1helper_str" ]]; then case "$line" in
                        auto|none|all|pikaur|apacman) ;;
                        *) continue
                esac; fi
                #validate notify_function_str
                if [[ "$varname" = "notify_function_str" ]]; then case "$line" in
                        auto|gdbus|desk|send) ;;
                        *) continue
                esac; fi
                #validate self_branch_str
                if [[ "$varname" = "self_branch_str" ]]; then case "$line" in
                        stable|beta) ;;
                        *) continue
                esac; fi

                conf_a[$varname]=$line
                echo "$varname" | grep -F "zflag:" >/dev/null && \
                    flag_a["$(echo "$varname" | cut -d ':' -f 2)"]="$line"

            fi
        fi
    done < "$xs_autoupdate_conf"; unset line; unset varname
fi
unset validconf

#Convert legacy settings

case "${conf_a[str_cleanLevel]}" in
    high) conf_a[cln_aurpkg_bool]="$ctrue";  conf_a[cln_aurbuild_bool]="$ctrue";  conf_a[cln_paccache_num]=0 ;;
    low)  conf_a[cln_aurpkg_bool]="$cfalse"; conf_a[cln_aurbuild_bool]="$cfalse"; conf_a[cln_paccache_num]=2 ;;
    off)  conf_a[cln_aurpkg_bool]="$cfalse"; conf_a[cln_aurbuild_bool]="$cfalse"; conf_a[cln_paccache_num]=-1
esac

[[ ! "${conf_a[bool_detectErrors]}" = "" ]]   && conf_a[notify_errors_bool]="${conf_a[bool_detectErrors]}"
[[ ! "${conf_a[bool_Downgrades]}" = "" ]]     && conf_a[update_downgrades_bool]="${conf_a[bool_Downgrades]}"
[[ ! "${conf_a[bool_notifyMe]}" = "" ]]       && conf_a[notify_1enable_bool]="${conf_a[bool_notifyMe]}"
[[ ! "${conf_a[bool_updateFlatpak]}" = "" ]]  && conf_a[flatpak_1enable_bool]="${conf_a[bool_updateFlatpak]}"
[[ ! "${conf_a[bool_updateKeys]}" = "" ]]     && conf_a[update_keys_bool]="${conf_a[bool_updateKeys]}"
[[ ! "${conf_a[str_ignorePackages]}" = "" ]]  && conf_a[main_ignorepkgs_str]="${conf_a[str_ignorePackages]}"
[[ ! "${conf_a[str_log_d]}" = "" ]]           && conf_a[main_logdir_str]="${conf_a[str_log_d]}"
[[ ! "${conf_a[str_mirrorCountry]}" = "" ]]   && conf_a[main_country_str]="${conf_a[str_mirrorCountry]}"
[[ ! "${conf_a[str_testSite]}" = "" ]]        && conf_a[main_testsite_str]="${conf_a[str_testSite]}"
[[ "${conf_a[aur_devel_bool]}" = "0" ]]       && conf_a[aur_devel_freq]="-1"
[[ "${conf_a[flatpak_1enable_bool]}" = "0" ]] && conf_a[flatpak_update_freq]="-1"
[[ ! "${conf_a[reboot_1enable_bool]}" = "" ]] && conf_a[reboot_1enable_num]="${conf_a[reboot_1enable_bool]}"
[[ ! "${conf_a[repair_pythonrebuild_bool]}" = "" ]] && conf_a[repair_aurrbld_bool]="${conf_a[repair_pythonrebuild_bool]}"

IFS=$' '; for i in $(sort <<< "$conf_legacy"); do
	unset conf_a[$i]
done; IFS=$DEFAULTIFS


# Init notifications

notierr(){ troubleqin "ERR: $1 specified for notifications but not available/functioning. There will be no notifications"; }
notierr2(){ troubleqin "ERR: No compatible notification method found. There will be no notifications"; }

if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then 

    [[ "${conf_a[notify_vsn_bool]}" = "$ctrue" ]] && notifyvsn="[$vsn]\n"

    noti_gdbus=$true; noti_desk=$true; noti_send=$true

    case ${conf_a[notify_function_str]} in
    "gdbus")
        noti_desk=$false; noti_send=$false
        gdbus help >/dev/null 2>&1 || notierr "gdbus" 
        ;;
    "desk")
        noti_gdbus=$false; noti_send=$false
        notify-desktop --help >/dev/null 2>&1 || notierr "notify-desktop"
        ;;
    "send")
        noti_gdbus=$false; noti_desk=$false
        notify-send --help >/dev/null 2>&1 || notierr "notify-send"
        ;;
    "auto")
        if notify-desktop --help >/dev/null 2>&1; then
            noti_gdbus=$false; noti_send=$false
            troubleqin "notify-desktop found, using for notifications"
        elif chk_pkgisinst plasma-desktop; then
            if notify-send --help >/dev/null 2>&1; then
                noti_gdbus=$false; noti_desk=$false
                troubleqin "WARN: KDE Plasma desktop found, falling back to legacy. Please install notify-desktop-git for fully-supported notifications in KDE Plasma"
            else
                noti_desk=$false; noti_send=$false
                troubleqin "ERR: KDE Plasma desktop found, but no compatible notification method found"
                if gdbus help >/dev/null 2>&1; then troubleqin "WARN: Attempting to use gdbus...(this will likely fail on KDE)"
                else noti_gdbus=$false; notierr2; fi
            fi
        else
            if gdbus help >/dev/null 2>&1; then noti_desk=$false; noti_send=$false; troubleqin "gdbus found, using for notifications"
            else noti_gdbus=$false; noti_desk=$false; noti_send=$false; notierr2; fi
        fi
        ;;
    esac

else noti_gdbus=$false; noti_desk=$false; noti_send=$false; fi


#---Main---

#Start Sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi

if pidof -o %PPID -x "$(basename "$0")">/dev/null; then exit 0; fi #Only 1 main instance allowed

#Init logs
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then conf_a[main_logdir_str]="/var/log/xs"; fi
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then
    echo "Critical error: could not create log directory"; sleep 10; exit; fi
log_d="${conf_a[main_logdir_str]}"; log_f="${log_d}/auto-update.log"; export log_f
if [ ! -f "$log_f" ]; then echo "init">$log_f; fi


#Init perst
if [ "${conf_a[main_perstdir_str]}" = "" ]; then perst_d="$log_d"
else perst_d="${conf_a[main_perstdir_str]}"; fi
mkdir -p "$perst_d"; if [ ! -d "$perst_d" ]; then
    conf_a[main_perstdir_str]="${conf_a[main_logdir_str]}"; perst_d="${conf_a[main_logdir_str]}"; fi
perst_f="${perst_d}/auto-update_persist.dat"; export perst_d

typeset -A rbld_a

typeset -A perst_a; perst_a=(
    [last_aur_update]="20000101"
    [last_aurdev_update]="20000101"
    [last_flatpak_update]="20000101"
    [last_keys_update]="20000101"
    [last_mirrors_update]="20000101"
)

validconf=$(echo "${!perst_a[*]}"|sed 's/ /\\|/g')
if [[ -f "$perst_f" ]]; then
    while read line; do
        line="$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)"
        if echo "$line" | grep -F '=' &>/dev/null; then
            varname="$(echo "$line" | cut -d '=' -f 1)"
            if ! echo $varname |grep "$validconf" >/dev/null; then
                echo "$varname"|grep -F "zrbld:" >/dev/null || continue
            fi
            line="$(echo "$line" | cut -d '=' -f 2-)"
            if [[ ! "$line" = "" ]]; then
                #validate timestamp
                line="$(cnvrt2_int "$line")"; [[ "$line" -lt "20000101" ]] && continue
                perst_a[$varname]=$line
                echo "$varname" | grep -F "zrbld:" >/dev/null && \
                    rbld_a["$(echo "$varname" | cut -d ':' -f 2)"]=$line
            fi
        fi
    done < "$perst_f"; unset line varname
fi; unset validconf

#Finish init
conf_export; perst_export
self_repo="https://raw.githubusercontent.com/lectrode/xs-update-manjaro"
echo "$(date) - XS-Update $vsndsp initialized..." |tee $log_f
troublem "Config file: $xs_autoupdate_conf"
troubleqout

#Wait up to 5 minutes for network
trouble "Waiting for network..."
waiting=1;waited=0; while [ $waiting = 1 ]; do
    test_online && waiting=0
    if [ $waiting = 1 ]; then
        if [ $waited -ge 60 ]; then exit; fi
        sleep 5; waited=$(($waited+1))
    fi
done; unset waiting waited

sleep 8 # In case connection just established

#Check for updates for self
if [[ "${conf_a[self_1enable_bool]}" = "$ctrue" ]]; then
    trouble "Checking for self-updates [branch: ${conf_a[self_branch_str]}]..."
    vsn_new="$(dl_outstd "$self_repo/master/vsn_${conf_a[self_branch_str]}" | tr -cd '[:alnum:]+-.')"
    if [[ ! "$(echo $vsn_new | cut -d '+' -f 1)" = "$(printf "$(echo $vsn_new | cut -d '+' -f 1)\n$vsn" | sort -V | head -n1)" ]]; then
        if dl_verify "selfupdate" "$self_repo/${vsn_new}/hash_auto-update-sh" "$self_repo/${vsn_new}/auto-update.sh"; then
            troublem "==================================="
            troublem "Updating script to $vsn_new..."
            troublem "==================================="
            mv -f '/tmp/xs-autmp-selfupdate/auto-update.sh' "$0"
            chmod +x "$0"; "$0" "XS"& exit 0
        fi
    fi; unset vsn_new; dl_clean "selfupdate"
fi

#wait up to 5 minutes for running instances of pacman/apacman/pikaur
trouble "Waiting for pacman/apacman/pikaur..."
waiting=1;waited=0; while [ $waiting = 1 ]; do
    isRunning=0; pgrep pacman >/dev/null && isRunning=1
    pgrep apacman >/dev/null && isRunning=1; pgrep pikaur >/dev/null && isRunning=1
    [[ $isRunning = 1 ]] || waiting=0
    if [ $waiting = 1 ]; then
        if [ $waited -ge 60 ]; then exit; fi
        sleep 5; waited=$(($waited+1))
    fi
done;  unset waiting waited isRunning

#remove .lck file (pacman is not running at this point)
if [[ -f "$(get_pacmancfg DBPath)db.lck" ]]; then rm -f "$(get_pacmancfg DBPath)db.lck"; fi

#init main script and background notifications
trouble "Init vars and notifier..."
rm -f "${perst_d}\auto-update_termnotify.dat" >/dev/null 2>&1
getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
    mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
    chown -R ${s_usr[$i]} "${s_home[$i]}/.cache/xs"; fi; i=$(($i+1)); done
"$0" "backnotify"& bkntfypid=$!
pacmirArgs="--geoip"
[[ "${conf_a[main_country_str]}" = "" ]] || pacmirArgs="-c ${conf_a[main_country_str]}"
[[ "${conf_a[main_ignorepkgs_str]}" = "" ]] || pacignore="--ignore ${conf_a[main_ignorepkgs_str]}"
[[ "${conf_a[update_downgrades_bool]}" = "$ctrue" ]] && pacdown="u"

#Check for, download, and install main updates
pacclean

if ! type pacman-mirrors >/dev/null 2>&1; then trouble "pacman-mirrors not found - skipping"
elif perst_isneeded "${conf_a[update_mirrors_freq]}" "${perst_a[last_mirrors_update]}"; then
    trouble "Updating Mirrors... [branch: $(pacman-mirrors -G 2>/dev/null)]"
    (pacman-mirrors $pacmirArgs || pacman-mirrors -g) 2>&1 |sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |tee -a $log_f
    err_mirrors=${PIPESTATUS[0]}; if [[ $err_mirrors -eq 0 ]]; then
        perst_update "last_mirrors_update"; else trouble "ERR: pacman-mirrors exited with code $err_mirrors"; fi
fi

if perst_isneeded "${conf_a[update_keys_freq]}" "${perst_a[last_keys_update]}"; then
    trouble "Refreshing keys..."; pacman-key --refresh-keys  2>&1 |tee -a $log_f
    err_keys=${PIPESTATUS[0]}; if [[ $err_keys -eq 0 ]]; then
        perst_update "last_keys_update"; else trouble "ERR: pacman-key exited with code $err_keys"; fi
fi

#While loop for updating main and AUR packages
#Any critical errors will disable further changes
while : ; do

#Does not support installs with xproto<=7.0.31-1
if chk_pkgisinst "xproto" && [[ "$(chk_pkgvsndiff "xproto" "7.0.31-1")" -le 0 ]]; then
    trouble "ERR: Critical: old xproto installed - system too old for script to update"; err_repo=1; break; fi

trouble "Downloading packages from main repos..."
pacman -Syyuw$pacdown --needed --noconfirm $pacignore 2>&1 |tee -a $log_f
err_repodl=${PIPESTATUS[0]}; if [[ $err_repodl -ne 0 ]]; then trouble "ERR: pacman exited with code $err_repodl"; fi

#Required manual pkg changes
if [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then

#Fix for pacman<5.2 (18.1.1 and earlier)
if [[ "$(chk_pkgvsndiff "pacman" "5.2.0-1")" -lt 0 ]]; then
    trouble "Old pacman detected, attempting to use pacman-static..."
    pacman -Sw --noconfirm pacman-static 2>&1 |tee -a $log_f
    pacman -U --noconfirm "$(get_pkgfilename "pacman-static")" 2>&1 |tee -a $log_f && pcmbin="pacman-static"
    if ! chk_pkgisinst "pacman-static"; then
        if dl_verify "pacmanstatic" "$self_repo/master/external/hash_pacman-static" "$self_repo/master/external/pacman-static"; then
            chmod +x /tmp/xs-autmp-pacmanstatic/pacman-static && pcmbin="/tmp/xs-autmp-pacmanstatic/pacman-static"; fi; fi
    if echo "$pcmbin"|grep "pacman-static" >/dev/null 2>&1 && $pcmbin --help >/dev/null 2>&1; then
        trouble "Using $pcmbin"
    else trouble "ERR: Critical: failed to use pacman-static. Cannot update system packages"; err_repo=1; break; fi
fi

#Removed from repos early December 2019
if chk_pkgisinst "pyqt5-common" && [[ "$(chk_pkgvsndiff "pyqt5-common" "5.13.2-1")" -le 0 ]]; then
    pacman -Rdd pyqt5-common --noconfirm 2>&1 |tee -a $log_f; fi
#Xfce 17.1.10 and earlier
if chk_pkgisinst "engrampa-thunar-plugin" && [[ "$(chk_pkgvsndiff "engrampa-thunar-plugin" "1.0-2")" -le 0 ]]; then
    pacman -Rdd engrampa-thunar-plugin --noconfirm 2>&1 |tee -a $log_f; fi

fi

trouble "Updating system packages..."
$pcmbin -S --needed --noconfirm $(for p in archlinux-keyring manjaro-keyring manjaro-system \
    ${conf_a[main_systempkgs_str]}; do chk_pkgisinst $p 1; done) 2>&1 |tee -a $log_f
err_sys=${PIPESTATUS[0]}; if [[ $err_sys -ne 0 ]]; then trouble "ERR: pacman exited with code $err_sys"; fi

#check for missing database files
if [[ "${conf_a[repair_db01_bool]}" = "$ctrue" ]]; then
    trouble "Checking for database errors..."
    i=-1; while IFS= read -r rp_errmsg; do
        if [[ ! "$rp_errmsg" = "" ]]; then
            ((i++))
            rp_pathf[$i]="$(echo "$rp_errmsg" | grep -o "/[[:alnum:]\.@_\/-]*")"
            troublem "Missing file: ${rp_pathf[$i]}"
            rp_pathd[$i]="$(dirname "${rp_pathf[$i]}")"
            troublem "detected dir: ${rp_pathd[$i]}"
            rp_pkgn[$i]="$(basename "${rp_pathd[$i]}"|grep -oP '.+?(?=-[0-9A-z\.\+:]+-[0-9]+$)')"
            troublem "detected pkg: ${rp_pkgn[$i]}"; mkdir -p "${rp_pathd[$i]}"
            if [[ ! -d "${rp_pathd[$i]}" ]]; then trouble "Err: mkdir failed: ${rp_pathd[$i]}"; break; fi
            touch "${rp_pathd[$i]}/files"; touch "${rp_pathd[$i]}/desc"
            if [[ ! -f "${rp_pathd[$i]}/files" ]] || [[ ! -f "${rp_pathd[$i]}/desc" ]]; then trouble "Err: could not touch files and/or desc"; continue; fi
        fi
    done< <($pcmbin -Qo pacman 2>&1 | grep -Ei "error: could not open file [[:alnum:]\.@_\/-]*\/(files|desc): No such file or directory")
    unset rp_errmsg; IFS=$DEFAULTIFS
    m=$i; i=-1; while [[ $i -lt $m ]]; do
        ((i++))
        troublem "reinstalling ${rp_pkgn[$i]}"
        $pcmbin -S --noconfirm --overwrite=* ${rp_pkgn[$i]} 2>&1 |tee -a $log_f
    done; unset i m rp_pathf[@] rp_pathd[@] rp_pkgn[@]
else if [[ "$($pcmbin -Dk 2>&1|grep -Ei "error:.+(description file|file list) is missing$"|wc -l)" -gt "0" ]]; then
    trouble "ERR: system has missing files in package database. Automatic fix disabled; reporting only."
fi; fi

sync; trouble "Updating packages from main repos..."
$pcmbin -Su$pacdown --needed --noconfirm $pacignore 2>&1 |tee -a $log_f
err_repo=${PIPESTATUS[0]}; if [[ $err_repo -ne 0 ]]; then trouble "ERR: pacman exited with code $err_repo"; break; fi
if [[ "${conf_a[aur_aftercritical_bool]}" = "$cfalse" ]]; then
    [[ "$(chk_crit)" = "crit" ]] && break
fi


# Init AUR selection
typeset -A hlpr_a; hlpr_a[apacman]=1; hlpr_a[pikaur]=1
if [[ "${conf_a[aur_update_freq]}" = "-1" ]] || [[ "${conf_a[aur_1helper_str]}" = "none" ]]; then break; fi
for helper in pikaur apacman; do
    if ! echo "${conf_a[aur_1helper_str]}" | grep "all\|auto\|$helper" >/dev/null; then hlpr_a[$helper]=0; continue; fi
    if ! type $helper >/dev/null 2>&1; then hlpr_a[$helper]=0
        if [[ "${conf_a[aur_1helper_str]}" = "$helper" ]]; then
            trouble "Warning: AURHelper: $helper specified but not found..."; fi
    fi
done
[[ "$((${hlpr_a[pikaur]}+${hlpr_a[apacman]}))" = "0" ]] && break

#check if AUR pkgs need rebuild
if [[ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]]; then
    if ! chk_pkgisinst "rebuild-detector"; then
        trouble "AUR Helper installed and enabled, and rebuilds are enabled. Installing missing dependency: rebuild-detector"
        $pcmbin -S --needed --noconfirm rebuild-detector 2>&1 |tee -a $log_f
    fi
    if chk_pkgisinst "rebuild-detector"; then
        trouble "Checking if AUR packages need rebuild..."
        for pkg in ${!rbld_a[*]}; do
            if perst_isneeded "${conf_a[repair_aurrbldfail_freq]}" "${perst_a[zrbld:$pkg]}"; then perst_reset "zrbld:$pkg"; continue; fi
        done
        rbaur_curpkg="$(aurrebuildlist)"
        if [[ "$rbaur_curpkg" = "" ]]; then unset rbaur_curpkg
            else trouble "AUR Rebuilds required; AUR timestamps have been reset"; perst_reset "last_aur_update"; fi
    fi
fi

if ! perst_isneeded "${conf_a[aur_update_freq]}" "${perst_a[last_aur_update]}";  then break; fi

#ensure pikaur functional if enabled
if [ "${hlpr_a[pikaur]}" = "1" ]; then
    pikpkg="$($pcmbin -Qq pikaur)"
    pikerr=0; pikaur -S --needed --noconfirm ${pikpkg:-pikaur} 2>&1 |tee -a $log_f
    if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then pikerr=1
        else pikaur -Q pikaur 2>&1|grep "rebuild" >/dev/null && pikerr=1
    fi
    if [[ "$pikerr" = "1" ]]; then
        trouble "Warning: AURHelper: pikaur not functioning"
        if [[ "${conf_a[repair_pikaur01_bool]}" = "$ctrue" ]] && $pcmbin -Q pikaur >/dev/null 2>&1; then
            troublem "Attempting to re-install ${pikpkg:-pikaur}..."
            mkdir "/tmp/xs-autmp-2delete"; pushd "/tmp/xs-autmp-2delete"
            git clone https://github.com/actionless/pikaur.git && cd pikaur
            python3 ./pikaur.py -S --rebuild --noconfirm ${pikpkg:-pikaur} 2>&1 |tee -a $log_f
            sync; popd; rm -rf /tmp/xs-autmp-2delete
        fi
        if ! pikaur --help >/dev/null 2>&1; then
            trouble "Warning: AURHelper: pikaur will be disabled"; fi
    fi
fi

if [[ "${conf_a[aur_1helper_str]}" = "auto" ]]; then
    if [ "${hlpr_a[pikaur]}" = "1" ]; then hlpr_a[apacman]=0; fi; fi


#Install KDE notifier dependency (if auto|desk on KDE)
if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then 
    if echo "${conf_a[notify_function_str]}"|grep "auto\|desk" >/dev/null; then
        if $pcmbin -Q plasma-desktop >/dev/null 2>&1; then
            if ! $pcmbin -Q notify-desktop-git; then
                if [ "${hlpr_a[pikaur]}" = "1" ]; then pikaur -S --needed --noconfirm notify-desktop-git; fi
                if [ "${hlpr_a[apacman]}" = "1" ]; then apacman -S --needed --noconfirm notify-desktop-git; fi
            fi
        fi
    fi
fi


#Update AUR packages

#rebuild AUR packages before AUR updates to minimize AUR package update failure
if [ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]; then
    if [[ ! "$rbaur_curpkg" = "" ]]; then
        trouble "Rebuilding AUR packages..."
        err_rbaur=0; while [[ ! "$rbaur_curpkg" = "$rbaur_oldpkg" ]]; do
            for pkg in $rbaur_curpkg; do
                troublem "Rebuilding/reinstalling $pkg"
                if [ "${hlpr_a[pikaur]}" = "1" ]; then
                    rbcst="$(echo "${!flag_a[*]}"|grep -E "(^|,)$pkg(,|$)")"
                    [[ ! "$rbcst" = "" ]] && rbcst_flg="--mflags=${flag_a[$rbcst]}"
                    test_online && pikaur -Sa --noconfirm $rbcst_flg $pkg 2>&1 |tee -a $log_f
                    err_rbaur=${PIPESTATUS[0]}; unset rbcst rbcst_flg
                elif [ "${hlpr_a[apacman]}" = "1" ]; then
                    apacman -S --auronly --noconfirm $pkg 2>&1 |tee -a $log_f
                    err_rbaur=${PIPESTATUS[0]}
                fi
            done
            rbaur_oldpkg="$rbaur_curpkg"; rbaur_curpkg="$(aurrebuildlist)"
        done; #let "err_aur=err_aur+err_rbaur"
        for pkg in $rbaur_curpkg; do perst_update "zrbld:$pkg"; done
    fi
fi; unset err_rbaur rbaur_curpkg rbaur_oldpkg

#AUR updates with pikaur
if [[ "${hlpr_a[pikaur]}" = "1" ]]; then
    if [[ ! "${#flag_a[@]}" = "0" ]]; then
        trouble "Updating AUR packages with custom flags [pikaur]..."
        for i in ${!flag_a[*]}; do
            for j in $(echo "$i" | tr ',' ' '); do
                $pcmbin -Q $j >/dev/null 2>&1 && custpkg+=" $j"; done
            if [[ ! "$custpkg" = "" ]]; then
                if test_online; then
                    troublem "Updating: $custpkg"
                    pikaur -S --needed --noconfirm --noprogressbar --mflags=${flag_a[$i]} $custpkg 2>&1 |tee -a $log_f
                    let "err_aur=err_aur+${PIPESTATUS[0]}"; unset custpkg
                else trouble "Not online - skipping pikaur command"; unset custpkg; break; fi
            fi
        done
    fi
    perst_isneeded "${conf_a[aur_devel_freq]}" "${perst_a[last_aurdev_update]}" && devel="--devel"
    if test_online; then
        trouble "Updating remaining AUR packages [pikaur $devel]..."
        pikaur -Sau$pacdown $devel --needed --noconfirm --noprogressbar $pacignore 2>&1 |tee -a $log_f
        let "err_aur=err_aur+${PIPESTATUS[0]}"; if [[ $err_aur -eq 0 ]]; then
            perst_update "last_aur_update"
            [[ "$devel" == "--devel" ]] && perst_update "last_aurdev_update"
        else trouble "ERR: pikaur exited with error"; fi
    else err_aur="1"; trouble "Not online - skipping pikaur command"; fi
fi

#AUR updates with apacman
if [[ "${hlpr_a[apacman]}" = "1" ]]; then
    # Workaround apacman script crash ( https://github.com/lectrode/xs-update-manjaro/issues/2 )
    dummystty="/tmp/xs-dummy/stty"
    mkdir $(dirname $dummystty)
    echo '#!/bin/sh' >$dummystty
    echo "echo 15" >>$dummystty
    chmod +x $dummystty
    export PATH=$(dirname $dummystty):$PATH

    trouble "Updating AUR packages [apacman]..."
    apacman -Su$pacdown --auronly --needed --noconfirm $pacignore 2>&1 |\
        sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |grep -Fv "%" |tee -a $log_f
    err_aur=${PIPESTATUS[0]}; if [[ $err_aur -eq 0 ]]; then 
        perst_update "last_aur_update"; else trouble "ERR: apacman exited with error"; fi
    if [ -d "$(dirname $dummystty)" ]; then rm -rf "$(dirname $dummystty)"; fi
fi


#End main and AUR updates
break
done

#Remove orphan packages, cleanup
if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]]; then 
    if [[ "${conf_a[cln_orphan_bool]}" = "$ctrue" ]] && [[ "$err_repo" = "0" ]]; then
        if [[ ! "$($pcmbin -Qtdq)" = "" ]]; then
            trouble "Removing orphan packages..."
            $pcmbin -Rnsc $($pcmbin -Qtdq) --noconfirm 2>&1 |tee -a $log_f
            err_orphan=${PIPESTATUS[0]}; [[ $err_orphan -gt 0 ]] && trouble "ERR: pacman exited with error code $err_orphan"
        fi
    fi
fi
pacclean
if [[ "$pcmbin" = "pacman-static" ]]; then $pcmbin -Rdd --noconfirm pacman-static 2>&1 |tee -a $log_f
    elif [[ ! "$pcmbin" = "pacman" ]]; then dl_clean "pacmanstatic"; fi

#Update Flatpak
if perst_isneeded "${conf_a[flatpak_update_freq]}" "${perst_a[last_flatpak_update]}"; then
    if flatpak --help >/dev/null 2>&1; then
        trouble "Updating flatpak..."
        flatpak update -y | grep -Fv "[" 2>&1 |tee -a $log_f
        err_fpak=${PIPESTATUS[0]}; if [[ $err_fpak -eq 0 ]]; then
            perst_update "last_flatpak_update"; else trouble "ERR: flatpak exited with error code $err_fpak"; fi
        if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[cln_flatpakorphan_bool]}" = "$ctrue" ]] && [[ "$err_fpak" = "0" ]]; then
            trouble "Removing unused flatpak packages..."
            flatpak uninstall --unused -y | grep -Fv "[" 2>&1 |tee -a $log_f
            err_fpakorphan=${PIPESTATUS[0]}; if [[ $err_fpakorphan -ne 0 ]]; then
                trouble "ERR: flatpak orphan removal exited with error code $err_fpakorphan"; fi
        fi
    fi
fi

#Finish
trouble "Update completed, final notifications and cleanup..."
touch "${perst_d}\auto-update_termnotify.dat"

msg="System update finished"
grep "Total Installed Size:\|new signatures:\|Total Removed Size:" $log_f >/dev/null || msg="$msg; no changes made"

if [ "${conf_a[notify_errors_bool]}" = "$ctrue" ]; then 
    trouble "error codes: [mirrors:$err_mirrors][sys:$err_sys][keys:$err_keys][repo:$err_repo][aur:$err_aur][fpak:$err_fpak][orphan:$err_orphan][fpakorphan:$err_fpakorphan]"
    [[ "$err_mirrors" -gt 0 ]] && errmsg="\n-Mirrors failed to update"
    [[ "$err_sys" -gt 0 ]] && errmsg="$errmsg \n-System packages failed to update"
    [[ "$err_keys" -gt 0 ]] && errmsg="$errmsg \n-Security signatures failed to update"
    [[ "$err_repo" -gt 0 ]] && errmsg="$errmsg \n-Packages from main repos failed to update"
    [[ "$err_aur" -gt 0 ]] && errmsg="$errmsg \n-Packages from AUR failed to update"
    [[ "$err_fpak" -gt 0 ]] && errmsg="$errmsg \n-Packages from Flatpak failed to update"
    [[ "$err_orphan" -gt 0 ]] && errmsg="$errmsg \n-Failed to remove orphan packages"
    [[ "$err_fpakorphan" -gt 0 ]] && errmsg="$errmsg \n-Failed to remove flatpak orphan packages"
    [[ "$errmsg" = "" ]] || msg="$msg \n\nSome update tasks encountered errors:$errmsg"
fi

if [ ! "$msg" = "System update finished; no changes made" ]; then 
    [[ "$msg" = "System update finished" ]] || msg="$msg\n"
    msg="$msg\nDetails: $log_f\n"
fi

if [[ "$(chk_crit)" = "norm" ]]; then
    if [[ "${conf_a[reboot_1enable_num]}" = "2" ]]; then
        exit_active "$msg\n"
    else
        iconnormal; sendall "$msg" "${conf_a[notify_lastmsg_num]}"
        exit_passive
    fi
else
    orig_log="$log_f"
    mv -f "$log_f" "${log_f}_$(date -I)"; log_f=${log_f}_$(date -I)
    echo "init">$orig_log

    activeExit=1; msgFail=0; [[ "${conf_a[reboot_1enable_num]}" -le "0" ]] && activeExit=0
    if [[ "$activeExit" = "0" ]]; then
        iconcritical; sendall "Kernel and/or drivers were updated. Please restart your $device to finish" || msgFail=1; fi
    if [[ "${conf_a[reboot_1enable_num]}" = "0" ]] && [[ "$msgFail" = "1" ]]; then activeExit=1; fi

    if [ "$activeExit" = "1" ]; then
        exit_active "Kernel and/or drivers were updated.\n"
    else
        exit_passive
    fi
fi

exit 1

