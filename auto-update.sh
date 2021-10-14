#!/bin/bash
#Auto Update For Manjaro by Lectrode
vsn="v3.9.0-rc3"; vsndsp="$vsn 2021-10-14"
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


if [ $# -eq 0 ]; then "$0" "XS"& exit 0; fi # fork to background (start with "nofork" parameter to avoid this)
debgn=+x; # -x =debugging | +x =no debugging


#---Define Functions---

to_int(){ [[ "$1" =~ ^[\-]?[0-9]+$ ]] && echo $1 || echo 0; }

trbl_out(){ echo -e "$@"; (echo -e "$@"|sed $ss_a |tr $ss_b)>> $log_f; }
trbl(){ trbl_out "\n${co_g}#XS# $(date) -${co_n} $@${co_n}\n"; }
trblm(){ trbl_out "${co_g2}XS-\033[0m$@${co_n}"; }

trblqin(){ ((logqueue_i++)); logqueue[$logqueue_i]="\n${co_g}#XS# $(date) -${co_n} $@${co_n}\n"; }
trblqout(){
    i=0; while [ $i -lt ${#logqueue[@]} ]; do
        trbl_out "${logqueue[$i]}"; ((i++))
    done; unset logqueue logqueue_i i
}

test_online(){ ping -c 1 "${conf_a[main_testsite_str]}" >/dev/null 2>&1 && return 0; return 1; }

pacclean(){
[[ ! "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] && return

[[ "$((conf_a[cln_aurpkg_bool]+conf_a[cln_aurbuild_bool]+conf_a[cln_paccache_num]))" -gt "-1" ]] && trbl "Performing cleanup operations..."

if [[ "${conf_a[cln_aurpkg_bool]}" = "$ctrue" ]]; then
    trblm "Cleaning AUR package cache..."
    if [ -d /var/cache/apacman/pkg ]; then rm -rf /var/cache/apacman/pkg/*; fi
    if [ -d /var/cache/pikaur/pkg ]; then rm -rf /var/cache/pikaur/pkg/*; fi
fi

if [[ "${conf_a[cln_aurbuild_bool]}" = "$ctrue" ]]; then
    trblm "Cleaning AUR build cache..."
    if [ -d /var/cache/pikaur/aur_repos ]; then rm -rf /var/cache/pikaur/aur_repos/*; fi
    if [ -d /var/cache/pikaur/build ]; then rm -rf /var/cache/pikaur/build/*; fi
fi

if [[ "${conf_a[cln_paccache_num]}" -gt "-1" ]]; then
    trblm "Cleaning pacman cache..."
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

chk_remoterepo(){ pacman -Slq 2>/dev/null|grep -E "^$1$" >/dev/null && return 0; return 1; }
chk_remoteaur(){ dl_outstd "${url_aur}?v=5&type=info&arg[]=$1" |grep -F '"resultcount":0' >/dev/null || return 0; return 1; }
chk_remoteany(){ chk_remoterepo $1 && return 0; chk_remoteaur $1 && return 0; return 1; }

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

get_pkgbuilddate(){
gpbd_date="$(pacman -Qi $1|grep "Build Date"|grep -oP "(?<=:[[:space:]]).*$" 2>/dev/null)"
[[ "$gpbd_date" = "" ]] && return 1
date -d "$gpbd_date" +'%Y%m%d' 2>/dev/null || return 1
unset gpbd_date; return 0
}

get_pacmancfg(){
#$1=prop
if pacman-conf --help >/dev/null 2>&1; then pacman-conf $1 2>/dev/null && return 0; fi
if [[ -f /etc/pacman.conf ]]; then
    gpcc="$(grep -E "^[^#]?$1" /etc/pacman.conf |sed -r 's/ += +/=/g'|cut -d'=' -f2)"
    if [[ ! "$gpcc" = "" ]]; then echo "$gpcc/"|sed -r 's_/+_/_g'; unset gpcc; return; fi; unset gpcc; fi
if [[ "$1" = "DBPath" ]]; then echo "/var/lib/pacman/"; fi
if [[ "$1" = "CacheDir" ]]; then echo "/var/cache/pacman/pkg/"; fi
}

chk_freespace(){
[[ "$(($(stat -f --format="%a*%S" "$1")))" -ge "$(($2*1024*1024*1024))" ]] && return 0
trbl "$co_r Less than $2GB free on $1; please free up some space"; return 1; }

chk_freespace_all(){
chk_freespace "$(get_pacmancfg CacheDir)" "2" || return 1
chk_freespace "/etc" "1" || return 1
chk_freespace "/" "2" || return 1
return 0
}

chk_crit(){
if grep -Ei "(up|down)(grad|dat)ing (linux[0-9]{2,3}|linux|systemd|mesa|(intel|amd)-ucode|cryptsetup|xf86-video)(\.|-| )" "$log_f"|grep -Fv "\-docs." >/dev/null
then echo crit; else echo norm; fi
}

manualRemoval(){
#$1=pkg|$2=vsn (or older) to remove|[$3 replacement pkg]
if chk_pkgisinst "$1" && [[ "$(chk_pkgvsndiff "$1" "$2")" -le 0 ]]; then
    trbl "attempting manual package removal/replacement of $1..."
    if [[ ! "$3" = "" ]]; then
        $pcmbin -Sw --noconfirm $3 $sf_ignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
        if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then trbl "$co_r failed to download $3"; return 1; fi
    fi
    pacman -Rdd --noconfirm $1 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    [[ "$3" = "" ]] || $pcmbin -S --noconfirm $3 $sf_ignore 2>&1 |tee -a $log_f
    if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then trbl "$co_r failed to replace $1 with $3"; return 1; fi
fi
}

disableSigsUpdate(){
[[ -f "/etc/pacman.conf.xsautoupdate.orig" ]] && mv -f "/etc/pacman.conf.xsautoupdate.orig" "/etc/pacman.conf"  2>&1 |tee -a $log_f
if cp -f "/etc/pacman.conf" "/etc/pacman.conf.xsautoupdate.orig" >/dev/null 2>&1; then
    sed -i 's/SigLevel.*/SigLevel = Never/' /etc/pacman.conf
    $pcmbin -S --noconfirm $1 $sf_ignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    mv -f "/etc/pacman.conf.xsautoupdate.orig" "/etc/pacman.conf"  2>&1 |tee -a $log_f
fi
$pcmbin -Quq|grep -E "^$1$" >/dev/null 2>&1 && return 1
return 0
}

#Persistant Data Functions

perst_isneeded(){
#$1 = frequency: xxxx_freq
#$2 = previous date: perst_a[last_xxxx]

    if [[ "$1" -eq "-1" ]]; then return 1; fi
    curdate=$(date +'%Y%m%d')
    scheddate=$(date -d "$2 + $1 days" +'%Y%m%d')

    if [[ "$scheddate" -le "$curdate" ]]; then return 0
    elif [[ "$2" -gt "$curdate" ]]; then return 0
    else return 1; fi
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
    IFS=$'\n'; for i in $(sort <<< "${!perst_a[@]}"); do
        echo "$i=${perst_a[$i]}" >> "$perst_f"
    done; unset IFS
}

perst_reset(){
#$1 = last_*
    if echo "$1" | grep -F "zrbld:" >/dev/null; then
        unset rbld_a["$(echo "$1" | cut -d ':' -f 2)"] perst_a[$1]
        perst_export #cannot use sed, as [] is treated as regex
    else perst_a[$1]="20010101"; echo "$1=20010101" >> "$perst_f"; fi
}

aurrebuildlist(){
    arlist=($(checkrebuild 2>/dev/null|grep -oP '^foreign[[:space:]]+\K(?!.*-bin$)([[:alnum:]\.@_\+\-]*)$'))

    #remove stale rebuild cache entries
    arlist_grep="$(echo -n "${arlist[@]}"|tr ' ' '|')"
    for pkg in ${!rbld_a[@]}; do
        if [[ "${#arlist[@]}" = "0" ]] || ! echo "$pkg"|grep -E "^($arlist_grep)$" >/dev/null; then
            perst_reset "zrbld:$pkg"; fi
    done

    #remove ignored entries
    arignore="$(echo -n $(echo "${conf_a[main_ignorepkgs_str]}"; get_pacmancfg IgnorePkg; echo "${!rbld_a[@]}")|tr '\n' ' '|sed 's/ /|/g')"
    [[ "$arignore" = "" ]] || arlist=($(echo "${arlist[@]}"|tr ' ' '\n'|grep -Evi "^($arignore)$"))
    
    #exclude orphan packages from list
    for pkg in ${arlist[@]}; do
        if ! chk_remoteaur $pkg; then
            [[ "${perst_a[$pkg]}" = "" ]] || perst_reset "zrbld:$pkg"
        else echo $pkg; fi
    done

    unset arlist arignore arlist_grep
}


#Notification Functions

iconnormal(){ icon=emblem-default; [[ -f "/usr/share/pixmaps/ElectrodeXS.png" ]] && icon=ElectrodeXS; }
iconwarn(){ icon=dialog-warning; }
iconcritical(){ icon=emblem-important; }
iconerror(){ icon=dialog-error; }

sendmsg(){
#$1=user; $2=msg; [$3=timeout]
    if [[ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]] && [[ "$((noti_desk+noti_send+noti_gdbus))" -le 2 ]]; then
        noti_id["$1"]="$(to_int "${noti_id["$1"]}")"
        tmp_t0="$(to_int "$3")"
        if [ "$tmp_t0" = "0" ]; then
            tmp_t1="-u critical"
        else ((tmp_t0*=1000)); tmp_t1="-t $tmp_t0"; fi
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
        loginctl show-session -p Active ${sssnarr[0]}|grep -F "yes" >/dev/null || continue
        usr="$(loginctl show-session -p Name ${sssnarr[0]}|cut -d'=' -f2)"
        disp="$(loginctl show-session -p Display ${sssnarr[0]}|cut -d'=' -f2)"
        [[ "$disp" = "" ]] && disp=":0" #workaround for gnome, which returns nothing
        usrhome="$(getent passwd "$usr"|cut -d: -f6)"
        [[  ${usr-x} && ${disp-x} && ${usrhome-x} ]] || continue
        s_usr[$i]=$usr; s_disp[$i]=$disp; s_home[$i]=$usrhome; ((i++)); IFS=$'\n\b';
    done; sleep 1
    unset IFS i usr disp usrhome sssnarr sssn
}

sendall(){
    if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then
        sa_err=0; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
            DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${s_usr[$i]})/bus" \
                sendmsg "${s_usr[$i]}" "$1" "$2" || sa_err=1
            ((i++))
        done; unset i; return $sa_err
    fi
}

backgroundnotify(){
iconwarn; while : ; do
    if [[ -f "${perst_d}/auto-update_termnotify.dat" ]]; then 
        sendall "dismiss"; rm -f "${perst_d}/auto-update_termnotify.dat"; sleep 2; exit 0; fi
    sleep 2; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
        if [ -f "${s_home[$i]}/.cache/xs/logonnotify" ]; then
            DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${s_usr[$i]})/bus" \
                sendmsg "${s_usr[$i]}" "System is updating (please do not turn off the $device)\nDetails: $log_f" \
                && rm -f "${s_home[$i]}/.cache/xs/logonnotify"
        fi; ((i++))
    done; [[ ${#s_usr[@]} -eq 0 ]] && sleep 3
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
    trbl "XS-done"; sync; n=0
    while jobs|grep Running >/dev/null && [[ $n -le 15 ]] ; do ((n++)); sleep 2; done
    systemctl stop xs-autoupdate.service >/dev/null 2>&1; exit 0
}

exit_active(){
#$1 = reason
    secremain=${conf_a[reboot_delay_num]}
    actn_cmd="${conf_a[reboot_action_str]}"
    ignoreusers="$(echo "${conf_a[reboot_ignoreusers_str]}" |sed 's/ /\\\|/g')"
    iconcritical; trbl "Active Exit: $actn_cmd";trbl "XS-done"; sync &
    while [ $secremain -gt 0 ]; do
        usersexist=$false; loginctl list-sessions --no-legend |grep -v "$ignoreusers" |grep "seat\|pts" >/dev/null && usersexist=$true

        if [ "${conf_a[reboot_delayiflogin_bool]}" = "$ctrue" ]; then
            if [ "$usersexist" = "$false" ]; then trblm "No logged-in users detected; System will $actn_cmd now"; secremain=0; sleep 1; continue; fi; fi

        if [[ "$usersexist" = "$true" ]]; then sendall "$1\nYour $device will $actn_cmd in \n$secremain seconds..."; fi
        sleep ${conf_a[reboot_notifyrep_num]}
        ((secremain-=conf_a[reboot_notifyrep_num]))
    done
    sync; $actn_cmd || systemctl --force $actn_cmd || systemctl --force --force $actn_cmd
}

conf_validstr(){ echo "$val" |grep -E "^($1)\$" >/dev/null || return 1; return 0; }

conf_valid(){
#parse and validate lines from config and persistant data files
parse="$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)"
echo "$parse" | grep -F '=' &>/dev/null || return 1

varname="$(echo "$parse" | cut -d '=' -f 1)"
val="$(echo "$line" | cut -d '=' -f 2-)"

if ! echo $varname |grep "$validconf" >/dev/null; then
    echo "$varname"|grep -E "^($1):" >/dev/null || return 1
fi
[[ "$val" = "" ]] && return 1

#validate zflag
if echo "$varname" | grep -E "^zflag:" >/dev/null; then
    return 0
fi

#validate zrbld/timestamp
if echo "$varname"|grep -E "(_(up)?date\$|^zrbld:)" >/dev/null; then
    val="$(to_int "$val")"; [[ "$val" -lt "20000101" ]] && return 1
    return 0
fi

#validate boolean
if echo "$varname" | grep -F "bool" >/dev/null; then
    [[ ( "$val" = "$ctrue" || "$val" = "$cfalse" ) ]] || return 1; return 0; fi

#validate numbers
if echo "$varname" | grep -E "_(num|freq)$" >/dev/null; then
    if [[ ! "$val" = "0" ]]; then val="$(to_int "$val")"
    [[ "$val" = "0" ]] && return 1; fi; fi
#validate integers 0+
if echo "$conf_int0" | grep "$varname" >/dev/null; then
    if [[ "$val" -lt "0" ]]; then return 1; fi; fi
#validate integers -1+
if echo "$conf_intn1" | grep "$varname" >/dev/null || echo "$varname" | grep -E "_freq$" >/dev/null; then
    if [[ "$val" -lt "-1" ]]; then return 1; fi; fi

#validate string settings

case "$varname" in
        reboot_action_str) conf_validstr "reboot|halt|poweroff|shutdown" || return 1 ;;
        aur_1helper_str) conf_validstr "auto|none|all|pikaur|apacman" || return 1 ;;
        notify_function_str) conf_validstr "auto|gdbus|desk|send" || return 1 ;;
        self_branch_str) conf_validstr "stable|beta" || return 1 ;;
esac

return 0
}

conf_export(){
[[ -d "$(dirname $xs_autoupdate_conf)" ]] || mkdir "$(dirname $xs_autoupdate_conf)"
cat << 'EOF' > "$xs_autoupdate_conf"
#Config for XS-AutoUpdate
# AUR Settings #
#aur_1helper_str:          Valid options are auto,none,all,pikaur,apacman
#aur_aftercritical_bool:   Enable/Disable AUR updates immediately after critical system updates
#aur_update_freq:          Update AUR packages every X days
#aur_devel_freq:           Update -git and -svn AUR packages every X days (-1 to disable, best if a multiple of aur_update_freq, pikaur only)

# Cleanup Settings #
#cln_1enable_bool:         Enable/Disable ALL package cleanup (overrides following cleanup settings)
#cln_aurpkg_bool:          Enable/Disable AUR package cleanup
#cln_aurbuild_bool:        Enable/Disable AUR build cleanup
#cln_flatpakorphan_bool:   Enable/Disable uninstall of uneeded flatpak packages
#cln_orphan_bool:          Enable/Disable uninstall of uneeded repo packages
#cln_paccache_num:         Number of official packages to keep (-1 to keep all)

# Flatpak Settings #
#flatpak_update_freq:      Check for Flatpak package updates every X days (-1 to disable)

# Notification Settings #
#notify_1enable_bool:      Enable/Disable nofications
#notify_function_str:      Valid options are auto,gdbus,desk,send
#notify_lastmsg_num:       Seconds before final normal notification expires (0=never)
#notify_errors_bool:       Include failed tasks in summary notification
#notify_vsn_bool:          Include version number in notifications

# Main Settings #
#main_ignorepkgs_str:      List of packages to ignore separated by spaces (in addition to pacman.conf)
#main_systempkgs_str:      List of packages to update before any other packages (i.e. archlinux-keyring)
#main_logdir_str:          Path to the log directory
#main_perstdir_str:        Path to the persistant timestamp directory (uses main_logdir_str if not defined)
#main_country_str:         Countries separated by commas from which to pull updates. Default is automatic (geoip)
#main_testsite_str:        URL (without protocol) used to test internet connection

# Reboot Settings #
#reboot_1enable_num:       Perform system power action: 2=always, 1=only after critical updates, 0=only if normal reboot may not be possible, -1=never
#reboot_action_str:        System power action. Valid options are reboot, halt, poweroff
#reboot_delayiflogin_bool: Only delay rebooting $device if users are logged in" >> "$xs_autoupdate_conf"
#reboot_delay_num:         Delay in seconds to wait before rebooting the $device" >> "$xs_autoupdate_conf"
#reboot_notifyrep_num:     Reboot notification is updated every X seconds. Best if reboot_delay_num is evenly divisible by this
#reboot_ignoreusers_str:   Ignore these users even if logged on. List users separated by spaces

# Automatic Repair Settings #
#repair_1enable_bool:      Enable/Disable all repairs
#repair_db01_bool:         Enable/Disable Repair missing "desc"/"files" files in package database
#repair_keyringpkg_bool:   Enable/Disable Manual update of obsolete keyring packages
#repair_manualpkg_bool:    Enable/Disable Perform critical package changes required for continued updates
#repair_pikaur01_bool:     Enable/Disable Re-install pikaur if not functioning
#repair_aurrbld_bool:      Enable/Disable Rebuild AUR packages after dependency updates (requires AUR helper enabled)
#repair_aurrbldfail_freq:  Retry rebuild/reinstall of AUR packages after dependency updates every X days (-1=never, 0=always)

# Self-update Settings #
#self_1enable_bool:        Enable/Disable updating self (this script)
#self_branch_str:          Update branch (this script only): stable, beta

# Update Settings #
#update_downgrades_bool:   Directs pacman to downgrade package if remote is older than local
#update_mirrors_freq:      Update mirror list every X days (-1 to disable)
#update_keys_freq:         Check for security signature/key updates every X days (-1 to disable)

# Custom Makepkg Flags for AUR packages (requires pikaur)
#zflag:packagename1,packagename2=--flag1,--flag2,--flag3


EOF
IFS=$'\n'; for i in $(sort <<< "${!conf_a[@]}"); do
	echo "$i=${conf_a[$i]}" >> "$xs_autoupdate_conf"
done; unset IFS
}



#----------------------
#---Initialize---
#----------------------

# misc vars

set $debgn; pcmbin="pacman"; pacmirArgs="--geoip"
true=0; false=1; ctrue=1; cfalse=0
ss_a='s/\x1B\[[0-9;]\+[A-Za-z]//g'; ss_b="-cd '\11\12\15\40-\176'"
co_n='\033[0m';co_g='\033[1;32m';co_g2='\033[0;32m';co_r='\033[1;31m[Error]';co_y='\033[1;33m[Warning]'
url_repo="https://raw.githubusercontent.com/lectrode/xs-update-manjaro"
url_aur="https://aur.archlinux.org/rpc/"
typeset -A err; typeset -A logqueue; logqueue_i=-1
[[ "$xs_autoupdate_conf" = "" ]] && xs_autoupdate_conf='/etc/xs/auto-update.conf'
device="device"; [[ "$(uname -m)" = "x86_64" ]] && device="computer"
sf_ignore="$(get_pacmancfg SyncFirst)"; if [[ ! "$sf_ignore" = "" ]]; then sf_ignore="--ignore $(echo $sf_ignore|sed -e 's/\s/ --ignore /g')"; fi

#config: defaults

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
    [repair_1enable_bool]=$ctrue
    [repair_db01_bool]=$ctrue
    [repair_keyringpkg_bool]=$ctrue
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

validconf=$(echo "${!conf_a[@]}"|sed 's/ /\\|/g')

conf_int0="notify_lastmsg_num reboot_delay_num reboot_notifyrep_num"
conf_intn1="cln_paccache_num reboot_1enable_num"
conf_legacy="bool_detectErrors bool_Downgrades bool_notifyMe bool_updateFlatpak bool_updateKeys str_cleanLevel \
    str_ignorePackages str_log_d str_mirrorCountry str_testSite aur_devel_bool flatpak_1enable_bool \
    reboot_1enable_bool repair_pythonrebuild_bool"

#config: load from file

if [[ -f "$xs_autoupdate_conf" ]]; then
    while read line; do

        #basic validation
        if ! conf_valid "zflag"; then
            [[ ! "$varname" = "" ]] && [[ ! "$val" = "" ]] && trblqin "$co_y invalid config data (reset/ignored): [$line]"
            continue
        fi

        #validate reboot_notifyrep_num
        if [[ "$varname" = "reboot_notifyrep_num" ]]; then
            if [[ "$val" -gt "${conf_a[reboot_delay_num]}" ]]; then
                val=${conf_a[reboot_delay_num]}; fi
            if [[ "$val" = "0" ]]; then
                val=1; fi
        fi

        [[ "$varname" = "reboot_action_str" ]] && [[ "$val" = "shutdown" ]] && val="poweroff"

        conf_a[$varname]=$val
        echo "$varname" | grep -F "zflag:" >/dev/null && \
            flag_a["$(echo "$varname" | cut -d ':' -f 2)"]="$val"

    done < "$xs_autoupdate_conf"; unset line parse varname val
fi
unset validconf

#config: convert legacy

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
done; unset IFS


# notifications: get method

notierr(){ trblqin "$co_r $1 specified for notifications but not available/functioning. There will be no notifications"; }
notierr2(){ trblqin "$co_r No compatible notification method found. There will be no notifications"; }

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
            trblqin "notify-desktop found, using for notifications"
        elif chk_pkgisinst plasma-desktop; then
            if notify-send --help >/dev/null 2>&1; then
                noti_gdbus=$false; noti_desk=$false
                trblqin "$co_y KDE Plasma desktop found, falling back to legacy. Please install notify-desktop-git for fully-supported notifications in KDE Plasma"
            else
                noti_desk=$false; noti_send=$false
                trblqin "$co_r KDE Plasma desktop found, but no compatible notification method found"
                if gdbus help >/dev/null 2>&1; then trblqin "$co_y Attempting to use gdbus...(this will likely fail on KDE)"
                else noti_gdbus=$false; notierr2; fi
            fi
        else
            if gdbus help >/dev/null 2>&1; then noti_desk=$false; noti_send=$false; trblqin "gdbus found, using for notifications"
            else noti_gdbus=$false; noti_desk=$false; noti_send=$false; notierr2; fi
        fi
        ;;
    esac

else noti_gdbus=$false; noti_desk=$false; noti_send=$false; fi



#sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi

if pidof -o %PPID -x "$(basename "$0")">/dev/null; then exit 0; fi #only 1 main instance allowed

#logs
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then conf_a[main_logdir_str]="/var/log/xs"; fi
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then
    echo "Critical error: could not create log directory"; sleep 10; exit; fi
log_d="${conf_a[main_logdir_str]}"; log_f="${log_d}/auto-update.log"
if [ ! -f "$log_f" ]; then echo "init">$log_f; fi


#perst
if [ "${conf_a[main_perstdir_str]}" = "" ]; then perst_d="$log_d"
else perst_d="${conf_a[main_perstdir_str]}"; fi
mkdir -p "$perst_d"; if [ ! -d "$perst_d" ]; then
    conf_a[main_perstdir_str]="${conf_a[main_logdir_str]}"; perst_d="${conf_a[main_logdir_str]}"; fi
perst_f="${perst_d}/auto-update_persist.dat"

typeset -A rbld_a
typeset -A perst_a; perst_a=(
    [last_aur_update]="20000101"
    [last_aurdev_update]="20000101"
    [last_flatpak_update]="20000101"
    [last_keys_update]="20000101"
    [last_mirrors_update]="20000101"
)

validconf=$(echo "${!perst_a[@]}"|sed 's/ /\\|/g')
if [[ -f "$perst_f" ]]; then
    while read line; do

        #basic validation
        if ! conf_valid "zrbld"; then
            [[ ! "$varname" = "" ]] && [[ ! "$val" = "" ]] && trblqin "$co_y invalid cache data (reset/ignored): [$line]"
            continue
        fi
        perst_a[$varname]=$val
        echo "$varname" | grep -F "zrbld:" >/dev/null && \
            rbld_a["$(echo "$varname" | cut -d ':' -f 2)"]=$val
    done < "$perst_f"; unset line parse varname val
fi; unset validconf

#finish init
conf_export; perst_export
export perst_d log_f #needed for backgroundnotify
[[ "${conf_a[main_country_str]}" = "" ]] || pacmirArgs="-c ${conf_a[main_country_str]}"
[[ "${conf_a[main_ignorepkgs_str]}" = "" ]] || pacignore="--ignore ${conf_a[main_ignorepkgs_str]}"
[[ "${conf_a[update_downgrades_bool]}" = "$ctrue" ]] && pacdown="u"
(echo)>$log_f;trbl "${co_g}XS-Update $vsndsp initialized..."
trblm "Config file: $xs_autoupdate_conf"; trblqout


#-----------------------
#---Main Script---
#-----------------------


#Wait up to 5 minutes for network
trbl "Waiting for network..."
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
    trbl "Checking for self-updates [branch: ${conf_a[self_branch_str]}]..."
    vsn_new="$(dl_outstd "$url_repo/master/vsn_${conf_a[self_branch_str]}" | tr -cd '[:alnum:]+-.')"
    if [[ ! "$(echo $vsn_new | cut -d '+' -f 1)" = "$(printf "$(echo $vsn_new | cut -d '+' -f 1)\n$vsn" | sort -V | head -n1)" ]]; then
        if dl_verify "selfupdate" "$url_repo/${vsn_new}/hash_auto-update-sh" "$url_repo/${vsn_new}/auto-update.sh"; then
            trblm "==================================="
            trblm "Updating script to $vsn_new..."
            trblm "==================================="
            mv -f '/tmp/xs-autmp-selfupdate/auto-update.sh' "$0"
            chmod +x "$0"; "$0" "XS"& exit 0
        fi
    fi; unset vsn_new; dl_clean "selfupdate"
fi

#wait up to 5 minutes for running instances of pacman/apacman/pikaur
trbl "Waiting for pacman/apacman/pikaur..."
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

#init background notifications
trbl "init notifier..."
rm -f "${perst_d}\auto-update_termnotify.dat" >/dev/null 2>&1
rm -f "${perst_d}/auto-update_termnotify.dat" >/dev/null 2>&1
getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
    mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
    chown -R ${s_usr[$i]} "${s_home[$i]}/.cache/xs"; fi; ((i++)); done
"$0" "backnotify"& bkntfypid=$!

#Check for, download, and install main updates
pacclean

if ! type pacman-mirrors >/dev/null 2>&1; then trbl "pacman-mirrors not found - skipping"
elif perst_isneeded "${conf_a[update_mirrors_freq]}" "${perst_a[last_mirrors_update]}"; then
    trbl "Updating Mirrors... [branch: $(pacman-mirrors -G 2>/dev/null)]"
    (pacman-mirrors $pacmirArgs || pacman-mirrors -g) 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    err[mirrors]=${PIPESTATUS[0]}; if [[ ${err[mirrors]} -eq 0 ]]; then
        perst_update "last_mirrors_update"; else trbl "$co_y pacman-mirrors exited with code ${err[mirrors]}"; fi
fi

if perst_isneeded "${conf_a[update_keys_freq]}" "${perst_a[last_keys_update]}"; then
    trbl "Refreshing keys..."; pacman-key --refresh-keys  2>&1 |tee -a $log_f |tee /dev/tty |grep "Total number processed:" >/dev/null
    err_keys=("${PIPESTATUS[@]}"); if [[ "${err_keys[0]}" -eq 0 ]] || [[ "${err_keys[3]}" -eq 0 ]]; then
        perst_update "last_keys_update"; err[keys]=0; else err[keys]=${err_keys[0]}; trbl "$co_y pacman-key exited with code ${err[keys]}"; fi
unset err_keys; fi

#While loop for updating main and AUR packages
#Any critical errors will disable further changes
while : ; do

if ! chk_freespace_all; then err[repo]=1; err_crit="repo"; break; fi

#Does not support installs with xproto<=7.0.31-1
if chk_pkgisinst "xproto" && [[ "$(chk_pkgvsndiff "xproto" "7.0.31-1")" -le 0 ]]; then
    trbl "$co_r old xproto installed - system too old for script to update"; err[repo]=1; err_crit="repo"; break; fi

trbl "Downloading packages from main repos..."
pacman -Syyuw$pacdown --needed --noconfirm $pacignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
err_repodl=${PIPESTATUS[0]}; if [[ $err_repodl -ne 0 ]]; then trbl "$co_y pacman failed to download packages - err code:$err_repodl"; fi

[[ "${conf_a[cln_paccache_num]}" = "0" ]] || pacclean
if ! chk_freespace_all; then err[repo]=1; err_crit="repo"; break; fi

#Required manual pkg changes
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then
    trbl "Checking for required manual package changes..."
    #Fix for pacman<5.2 (18.1.1 and earlier)
    if [[ "$(chk_pkgvsndiff "pacman" "5.2.0-1")" -lt 0 ]]; then
        trbl "Old pacman detected, attempting to use pacman-static..."
        pacman -Sw --noconfirm pacman-static 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
        pacman -U --noconfirm "$(get_pkgfilename "pacman-static")" 2>&1 |sed $ss_a |tr $ss_b|tee -a $log_f && pcmbin="pacman-static"
        if ! chk_pkgisinst "pacman-static"; then
            if dl_verify "pacmanstatic" "$url_repo/master/external/hash_pacman-static" "$url_repo/master/external/pacman-static"; then
                chmod +x /tmp/xs-autmp-pacmanstatic/pacman-static && pcmbin="/tmp/xs-autmp-pacmanstatic/pacman-static"; fi; fi
        if echo "$pcmbin"|grep "pacman-static" >/dev/null 2>&1 && $pcmbin --help >/dev/null 2>&1; then
            trbl "Using $pcmbin"
        else trbl "$co_r failed to use pacman-static. Cannot update system packages"; err[repo]=1; err_crit="repo"; break; fi
    fi
fi

#Update keyring packages
trbl "Updating system keyrings..."
for p in $(pacman -Sl core | grep "\[installed"|grep -oP "[^ ]*\-keyring"); do
    $pcmbin -S --needed --noconfirm $p $sf_ignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    if [[ "${PIPESTATUS[0]}" -gt 0 ]]; then
        if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_keyringpkg_bool]}" = "$ctrue" ]]; then
            kr_date="$(get_pkgbuilddate $p)"; if [[ "$kr_date" = "" ]]; then kr_date="20000101"; fi
            #if build date of the keyring package is 546 or more days ago (~1.5 years), assume too old to update normally
            if perst_isneeded 546 "$kr_date"; then
                trblm "[$p] is old and failed to update; attempting fix..."
                if ! disableSigsUpdate "$p"; then trbl "$co_r could not update [$p]"; err[sys]=1; break; fi; fi
        else err[sys]=1; fi
    fi
done
if [[ ${err[sys]} -ne 0 ]]; then trbl "$co_r failed to update system keyrings"; err_crit="sys"; break; fi

if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then
    manualRemoval "libcanberra-gstreamer" "0.30+2+gc0620e4-3"; manualRemoval "lib32-libcanberra-gstreamer" "0.30+2+gc0620e4-3" #consolidated with lib32-/libcanberra-pulse 2021/06
    manualRemoval "python2-dbus" "1.2.16-3" #Removed from dbus-python 2021/03
    manualRemoval "pyqt5-common" "5.13.2-1" #Removed from repos early 2019/12
    manualRemoval "ilmbase" "2.3.0-1" #Merged into openexr 2019/10
    manualRemoval "colord" "1.4.4-1" #Conflicts with libcolord mid-2019
    manualRemoval "gtk3-classic" "3.24.24-1" "gtk3"; manualRemoval "lib32-gtk3-classic" "3.24.24-1" "lib32-gtk3" #Replaced around 18.0.4
    manualRemoval "engrampa-thunar-plugin" "1.0-2" #Xfce 17.1.10 and earlier
fi

trbl "Updating system packages..."
for p in $(pacman -Sl core | grep "\[installed"|grep -oP "[^ ]*\-system") ${conf_a[main_systempkgs_str]}; do
    chk_pkgisinst $p && $pcmbin -S --needed --noconfirm $p 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    ((err[sys]+=PIPESTATUS[0])); done
if [[ ${err[sys]} -ne 0 ]]; then trbl "$co_y system packages failed to update - err:${err[sys]}"; fi

#check for missing database files
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_db01_bool]}" = "$ctrue" ]]; then
    trbl "Checking for database errors..."
    i=-1; while IFS= read -r rp_errmsg; do
        if [[ ! "$rp_errmsg" = "" ]]; then
            ((i++))
            rp_pathf[$i]="$(echo "$rp_errmsg" | grep -o "/[[:alnum:]\.@_\/-]*")"
            trblm "Missing file: ${rp_pathf[$i]}"
            rp_pathd[$i]="$(dirname "${rp_pathf[$i]}")"
            trblm "detected dir: ${rp_pathd[$i]}"
            rp_pkgn[$i]="$(basename "${rp_pathd[$i]}"|grep -oP '.+?(?=-[0-9A-z\.\+:]+-[0-9]+$)')"
            trblm "detected pkg: ${rp_pkgn[$i]}"; mkdir -p "${rp_pathd[$i]}"
            if [[ ! -d "${rp_pathd[$i]}" ]]; then trbl "$co_y mkdir failed: ${rp_pathd[$i]}"; break; fi
            touch "${rp_pathd[$i]}/files"; touch "${rp_pathd[$i]}/desc"
            if [[ ! -f "${rp_pathd[$i]}/files" ]] || [[ ! -f "${rp_pathd[$i]}/desc" ]]; then trbl "$co_y could not touch files and/or desc"; continue; fi
        fi
    done< <($pcmbin -Qo pacman 2>&1 | grep -Ei "error: could not open file [[:alnum:]\.@_\/-]*\/(files|desc): No such file or directory")
    unset rp_errmsg IFS
    m=$i; i=-1; while [[ $i -lt $m ]]; do
        ((i++))
        trblm "reinstalling ${rp_pkgn[$i]}"
        $pcmbin -S --noconfirm --overwrite=* ${rp_pkgn[$i]} 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    done; unset i m rp_pathf[@] rp_pathd[@] rp_pkgn[@]
else if [[ "$($pcmbin -Dk 2>&1|grep -Ei "error:.+(description file|file list) is missing$"|wc -l)" -gt "0" ]]; then
    trbl "$co_y system has missing files in package database. Automatic fix disabled; reporting only."
fi; fi

sync; trbl "Updating packages from main repos..."
$pcmbin -Su$pacdown --needed --noconfirm $pacignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
err[repo]=${PIPESTATUS[0]}; if [[ ${err[repo]} -ne 0 ]]; then trbl "$co_r pacman exited with code ${err[repo]}"; err_crit="repo"; break; fi
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
            trbl "$co_y AURHelper: $helper specified but not found..."; fi
    fi
done
[[ "$((${hlpr_a[pikaur]}+${hlpr_a[apacman]}))" = "0" ]] && break

#check if AUR pkgs need rebuild
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]]; then
    if ! chk_pkgisinst "rebuild-detector"; then
        trbl "AUR Helper installed and enabled, and rebuilds are enabled. Installing missing dependency: rebuild-detector"
        $pcmbin -S --needed --noconfirm rebuild-detector 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    fi
    if chk_pkgisinst "rebuild-detector"; then
        trbl "Checking if AUR packages need rebuild..."
        for pkg in ${!rbld_a[@]}; do
            if perst_isneeded "${conf_a[repair_aurrbldfail_freq]}" "${perst_a[zrbld:$pkg]}"; then perst_reset "zrbld:$pkg"; continue; fi
        done
        rbaur_curpkg="$(aurrebuildlist)"
        if [[ "$rbaur_curpkg" = "" ]] || [[ "$rbaur_curpkg" =~ ^[[:space:]]+$ ]]; then unset rbaur_curpkg
            else trblm "AUR Rebuilds required; AUR timestamps have been reset"; perst_reset "last_aur_update"; fi
    fi
fi

if ! perst_isneeded "${conf_a[aur_update_freq]}" "${perst_a[last_aur_update]}";  then break; fi

#ensure pikaur functional if enabled
if [ "${hlpr_a[pikaur]}" = "1" ]; then
    pikpkg="$($pcmbin -Qq pikaur)"
    pikerr=0; pikaur -S --needed --noconfirm ${pikpkg:-pikaur} 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then pikerr=1
        else pikaur -Q pikaur 2>&1|grep "rebuild" >/dev/null && pikerr=1
    fi
    if [[ "$pikerr" = "1" ]]; then
        trbl "$co_y AURHelper: pikaur not functioning"
        if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_pikaur01_bool]}" = "$ctrue" ]] && $pcmbin -Q pikaur >/dev/null 2>&1; then
            trblm "Attempting to re-install ${pikpkg:-pikaur}..."
            mkdir "/tmp/xs-autmp-2delete"; pushd "/tmp/xs-autmp-2delete"
            git clone https://github.com/actionless/pikaur.git && cd pikaur
            python3 ./pikaur.py -S --rebuild --noconfirm ${pikpkg:-pikaur} 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
            sync; popd; rm -rf /tmp/xs-autmp-2delete
        fi
        if ! pikaur --help >/dev/null 2>&1; then
            trbl "$co_y AURHelper: pikaur will be disabled"; fi
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
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]]; then
    if [[ ! "$rbaur_curpkg" = "" ]]; then
        trbl "Rebuilding AUR packages..."
        err_rbaur=0; while [[ ! "$rbaur_curpkg" = "$rbaur_oldpkg" ]]; do
            for pkg in $rbaur_curpkg; do
                trblm "Rebuilding/reinstalling $pkg"
                if [ "${hlpr_a[pikaur]}" = "1" ]; then
                    rbcst="$(echo "${!flag_a[@]}"|grep -E "(^|,)$pkg(,|$)")"
                    [[ ! "$rbcst" = "" ]] && rbcst_flg="--mflags=${flag_a[$rbcst]}"
                    test_online && pikaur -Sa --noconfirm $rbcst_flg $pkg 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
                    err_rbaur=${PIPESTATUS[0]}; unset rbcst rbcst_flg
                elif [ "${hlpr_a[apacman]}" = "1" ]; then
                    apacman -S --auronly --noconfirm $pkg 2>&1 |tee -a $log_f
                    err_rbaur=${PIPESTATUS[0]}
                fi
            done
            rbaur_oldpkg="$rbaur_curpkg"; rbaur_curpkg="$(aurrebuildlist)"
        done; for pkg in $rbaur_curpkg; do perst_update "zrbld:$pkg"; done
    fi
fi; unset err_rbaur rbaur_curpkg rbaur_oldpkg

#AUR updates with pikaur
if [[ "${hlpr_a[pikaur]}" = "1" ]]; then
    if [[ ! "${#flag_a[@]}" = "0" ]]; then
        trbl "Updating AUR packages with custom flags [pikaur]..."
        for i in ${!flag_a[@]}; do
            for j in $(echo "$i" | tr ',' ' '); do
                $pcmbin -Q $j >/dev/null 2>&1 && custpkg+=" $j"; done
            if [[ ! "$custpkg" = "" ]]; then
                if test_online; then
                    trblm "Updating: $custpkg"
                    pikaur -S --needed --noconfirm --noprogressbar --mflags=${flag_a[$i]} $custpkg 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
                    ((err[aur]+=PIPESTATUS[0])); unset custpkg
                else trbl "$co_y not online - skipping pikaur command"; unset custpkg; break; fi
            fi
        done
    fi
    perst_isneeded "${conf_a[aur_devel_freq]}" "${perst_a[last_aurdev_update]}" && devel="--devel"
    if test_online; then
        trbl "Updating remaining AUR packages [pikaur $devel]..."
        pikaur -Sau$pacdown $devel --needed --noconfirm --noprogressbar $pacignore 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
        ((err[aur]+=PIPESTATUS[0])); if [[ ${err[aur]} -eq 0 ]]; then
            perst_update "last_aur_update"
            [[ "$devel" == "--devel" ]] && perst_update "last_aurdev_update"
        else trbl "$co_y pikaur exited with error"; fi
    else err[aur]="1"; trbl "$co_y not online - skipping pikaur command"; fi
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

    trbl "Updating AUR packages [apacman]..."
    apacman -Su$pacdown --auronly --needed --noconfirm $pacignore 2>&1 |sed $ss_a|tr $ss_b|grep -Fv "%" |tee -a $log_f
    err[aur]=${PIPESTATUS[0]}; if [[ ${err[aur]} -eq 0 ]]; then 
        perst_update "last_aur_update"; else trbl "$co_y apacman exited with error"; fi
    if [ -d "$(dirname $dummystty)" ]; then rm -rf "$(dirname $dummystty)"; fi
fi


#End main and AUR updates
break
done

#Remove orphan packages, cleanup
if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]]; then 
    if [[ "${conf_a[cln_orphan_bool]}" = "$ctrue" ]] && [[ "${err[repo]}" = "0" ]]; then
        if [[ ! "$($pcmbin -Qtdq)" = "" ]]; then
            trbl "Removing orphan packages..."
            $pcmbin -Rnsc $($pcmbin -Qtdq) --noconfirm 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
            err[orphan]=${PIPESTATUS[0]}; [[ ${err[orphan]} -gt 0 ]] && trbl "$co_y pacman exited with error code ${err[orphan]}"
        fi
    fi
fi
pacclean
if [[ "$pcmbin" = "pacman-static" ]]; then $pcmbin -Rdd --noconfirm pacman-static 2>&1 |sed $ss_a|tr $ss_b|tee -a $log_f
    elif [[ ! "$pcmbin" = "pacman" ]]; then dl_clean "pacmanstatic"; fi

#Update Flatpak
if perst_isneeded "${conf_a[flatpak_update_freq]}" "${perst_a[last_flatpak_update]}"; then
    if flatpak --help >/dev/null 2>&1; then
        trbl "Updating flatpak..."
        flatpak update -y | grep -Fv "[" 2>&1 |tee -a $log_f
        err[fpak]=${PIPESTATUS[0]}; if [[ ${err[fpak]} -eq 0 ]]; then
            perst_update "last_flatpak_update"; else trbl "$co_y flatpak exited with error code ${err[fpak]}"; fi
        if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[cln_flatpakorphan_bool]}" = "$ctrue" ]] && [[ "${err[fpak]}" = "0" ]]; then
            trbl "Removing unused flatpak packages..."
            flatpak uninstall --unused -y | grep -Fv "[" 2>&1 |tee -a $log_f
            err[fpakorphan]=${PIPESTATUS[0]}; if [[ ${err[fpakorphan]} -ne 0 ]]; then
                trbl "$co_y flatpak orphan removal exited with error code ${err[fpakorphan]}"; fi
        fi
    fi
fi

#Finish
trbl "Update completed, final notifications and cleanup..."
touch "${perst_d}/auto-update_termnotify.dat"

#Log error codes
[[ "$(( $(echo ${err[@]}|sed 's/ /+/g') ))" = "0" ]] || codes="$co_y"
iconnormal; if [[ ! "$err_crit" = "" ]]; then codes="$co_r"; iconerror; fi
trbl "$(
	echo -n "$codes${co_n} error codes: "
	for i in sys repo mirrors keys aur fpak orphan fpakorphan; do
        if [[ "$err_crit" = "$i" ]]; then echo -n "\033[1;31m[$i:${err[$i]}]"
        elif [[ ! "$((err[$i]+0))" = "0" ]]; then echo -n "\033[1;33m[$i:${err[$i]}]"
        else echo -n "$co_n[$i:${err[$i]}]"; fi
    done
)"

msg="System update finished"
grep "Total Installed Size:\|new signatures:\|Total Removed Size:" $log_f >/dev/null || msg="$msg; no changes made"

if [ "${conf_a[notify_errors_bool]}" = "$ctrue" ]; then 
    [[ "${err[mirrors]}" -gt 0 ]] && errmsg="\n-Mirrors failed to update"
    [[ "${err[sys]}" -gt 0 ]] && errmsg="$errmsg \n-System packages failed to update"
    [[ "${err[keys]}" -gt 0 ]] && errmsg="$errmsg \n-Security signatures failed to update"
    [[ "${err[repo]}" -gt 0 ]] && errmsg="$errmsg \n-Packages from main repos failed to update"
    [[ "${err[aur]}" -gt 0 ]] && errmsg="$errmsg \n-Packages from AUR failed to update"
    [[ "${err[fpak]}" -gt 0 ]] && errmsg="$errmsg \n-Packages from Flatpak failed to update"
    [[ "${err[orphan]}" -gt 0 ]] && errmsg="$errmsg \n-Failed to remove orphan packages"
    [[ "${err[fpakorphan]}" -gt 0 ]] && errmsg="$errmsg \n-Failed to remove flatpak orphan packages"
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
        sendall "$msg" "${conf_a[notify_lastmsg_num]}"
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

