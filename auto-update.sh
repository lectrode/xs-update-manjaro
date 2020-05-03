#!/bin/bash
#Auto Update For Manjaro by Lectrode
vsn="v3.2.4"; vsndsp="$vsn 2020-05-02"
#-Downloads and Installs new updates
#-Depends: pacman, paccache
#-Optional Depends: notification daemon, pikaur, apacman (deprecated)
true=0; false=1; ctrue=1; cfalse=0;


[[ "$xs_autoupdate_conf" = "" ]] && xs_autoupdate_conf='/etc/xs/auto-update.conf'
debgn=+x; # -x =debugging | +x =no debugging
set $debgn

#---Define Functions---

trouble(){ (echo;echo "#XS# `date` - $@") |tee -a $log_f; }
troublem(){ echo "XS-$@" |tee -a $log_f; }

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

conf_export(){
if [ ! -d `dirname $xs_autoupdate_conf` ]; then mkdir `dirname $xs_autoupdate_conf`; fi
echo '#Config for XS-AutoUpdate' > "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# AUR Settings #' >> "$xs_autoupdate_conf"
echo '#aur_1helper_str:          Valid options are auto,none,all,pikaur,apacman' >> "$xs_autoupdate_conf"
echo '#aur_update_freq:          Update AUR packages every X days' >> "$xs_autoupdate_conf"
echo '#aur_devel_freq:           Update -git and -svn AUR packages every X days (-1 to disable, best if a multiple of aur_update_freq, pikaur only)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Cleanup Settings #' >> "$xs_autoupdate_conf"
echo '#cln_1enable_bool:         Enables/disables ALL package cleanup (overrides following cleanup settings)' >> "$xs_autoupdate_conf"
echo '#cln_aurpkg_bool:          Enables/disables AUR package cleanup' >> "$xs_autoupdate_conf"
echo '#cln_aurbuild_bool:        Enables/disables AUR build cleanup' >> "$xs_autoupdate_conf"
echo '#cln_orphan_bool:          Enables/disables uninstall of uneeded packages' >> "$xs_autoupdate_conf"
echo '#cln_paccache_num:         Number of official packages to keep (-1 to keep all)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Flatpak Settings #' >> "$xs_autoupdate_conf"
echo '#flatpak_update_freq:      Check for Flatpak package updates every X days (-1 to disable)' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Notification Settings #' >> "$xs_autoupdate_conf"
echo '#notify_1enable_bool:      Enable/Disable nofications' >> "$xs_autoupdate_conf"
echo '#notify_lastmsg_num:       Seconds before final normal notification expires (0=never)' >> "$xs_autoupdate_conf"
echo '#notify_errors_bool:       Include possible errors in notifications' >> "$xs_autoupdate_conf"
echo '#notify_vsn_bool:          Include version number in notifications' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Main Settings #' >> "$xs_autoupdate_conf"
echo '#main_ignorepkgs_str:      List of packages to ignore separated by spaces (in addition to pacman.conf)' >> "$xs_autoupdate_conf"
echo '#main_logdir_str:          Path to the log directory' >> "$xs_autoupdate_conf"
echo '#main_perstdir_str:        Path to the persistant timestamp directory (uses main_logdir_str if not defined)' >> "$xs_autoupdate_conf"
echo '#main_country_str:         Countries separated by commas from which to pull updates. Default is automatic (geoip)' >> "$xs_autoupdate_conf"
echo '#main_testsite_str:        URL (without protocol) used to test internet connection' >> "$xs_autoupdate_conf"
echo '#' >> "$xs_autoupdate_conf"
echo '# Reboot Settings #' >> "$xs_autoupdate_conf"
echo '#reboot_1enable_bool:      Enables/Disables automatic reboot after critical updates' >> "$xs_autoupdate_conf"
echo '#reboot_delayiflogin_bool: Only delay rebooting computer if users are logged in' >> "$xs_autoupdate_conf"
echo '#reboot_delay_num:         Delay in seconds to wait before rebooting the computer' >> "$xs_autoupdate_conf"
echo '#reboot_notifyrep_num:     Reboot notification is updated every X seconds. Best if reboot_delay_num is evenly divisible by this' >> "$xs_autoupdate_conf"
echo '#reboot_ignoreusers_str:   Ignore these users even if logged on. List users separated by spaces' >> "$xs_autoupdate_conf"
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
DEFAULTIFS=$IFS; IFS=$'\n'
for i in $(sort <<< "${!conf_a[*]}"); do
	echo "$i=${conf_a[$i]}" >> "$xs_autoupdate_conf"
done; IFS=$DEFAULTIFS
}

#Persistant Data Functions

perst_isneeded(){
#$1 = frequency: xxxx_freq
#$2 = previous date: perst_a[last_xxxx]

    if [[ "$1" -eq "-1" ]]; then return 1; fi
    curdate=`date +'%Y%m%d'`
    scheddate=`date -d "$2 + $1 days" +'%Y%m%d'`
    
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
    perst_a[$1]=`date +'%Y%m%d'`
    echo "$1=`date +'%Y%m%d'`" >> "$perst_f"
}

perst_export(){
    touch "$perst_f"
    echo "#Last day specific tasks were performed" > "$perst_f"

    DEFAULTIFS=$IFS; IFS=$'\n'
    for i in $(sort <<< "${!perst_a[*]}"); do
        echo "$i=${perst_a[$i]}" >> "$perst_f"
    done; IFS=$DEFAULTIFS
}


#Notification Functions

killmsg(){ if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then killall xfce4-notifyd 2>/dev/null; fi; }
iconnormal(){ icon=ElectrodeXS; }
iconwarn(){ icon=important; }
iconcritical(){ icon=system-shutdown; }

sendmsg(){
    if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then
        DISPLAY=$2 su $1 -c "notify-send -i $icon XS-AutoUpdate -u critical \"$notifyvsn$3\"" & fi
}

sendall(){
    if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]; then
        getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
            sendmsg "${s_usr[$i]}" "${s_disp[$i]}" "$1"; i=$(($i+1))
        done; unset i
    fi
}

finalmsg_normal(){
    killmsg; iconnormal; sendall "$msg"; if [ ! "${conf_a[notify_lastmsg_num]}" = "0" ]; then
        sleep ${conf_a[notify_lastmsg_num]}; killmsg; fi
}

finalmsg_critical(){
    killmsg; iconcritical
    
    orig_log="$log_f"
    mv -f "$log_f" "${log_f}_`date -I`"; log_f=${log_f}_`date -I`
    
    if [ "${conf_a[reboot_1enable_bool]}" = "$ctrue" ]; then
    
        trouble "XS-done"
        secremain=${conf_a[reboot_delay_num]}
        echo "init">$orig_log
        ignoreusers=`echo "${conf_a[reboot_ignoreusers_str]}" |sed 's/ /\\\|/g'`
        while [ $secremain -gt 0 ]; do
            usersexist=$false; loginctl list-sessions --no-legend |grep -v "$ignoreusers" |grep "seat\|pts" >/dev/null && usersexist=$true
            
            if [ "${conf_a[reboot_delayiflogin_bool]}" = "$ctrue" ]; then
                if [ "$usersexist" = "$false" ]; then troublem "No logged-in users detected, rebooting now"; secremain=0; sleep 1; continue; fi; fi
            
            if [[ "$usersexist" = "$true" ]]; then killmsg; sendall "Kernel and/or drivers were updated.\nYour computer will automatically restart in \n$secremain seconds..."; fi
            sleep ${conf_a[reboot_notifyrep_num]}
            let secremain-=${conf_a[reboot_notifyrep_num]}
        done

        reboot
    else
        sendall "Kernel and/or drivers were updated. Please restart your computer to finish"
    fi
}

getsessions(){
    DEFAULTIFS=$IFS; IFS=$'\n\b';
    unset s_usr[@]; unset s_disp[@]; unset s_home[@]
    i=0; for sssn in `loginctl list-sessions --no-legend`; do
        IFS=' '; sssnarr=($sssn)
        actv=$(loginctl show-session -p Active ${sssnarr[0]}|cut -d '=' -f 2)
        [[ "$actv" = "yes" ]] || continue
        usr=$(loginctl show-session -p Name ${sssnarr[0]}|cut -d '=' -f 2)
        disp=$(loginctl show-session -p Display ${sssnarr[0]}|cut -d '=' -f 2)
        usrhome=$(getent passwd "$usr"|cut -d: -f6) #alt: eval echo "~$usr"
        [[  ${usr-x} && ${disp-x} && ${usrhome-x} ]] || continue
        s_usr[$i]=$usr; s_disp[$i]=$disp; s_home[$i]=$usrhome; i=$(($i+1)); IFS=$'\n\b';
    done
    if [ ${#s_usr[@]} -eq 0 ]; then sleep 5; fi
    IFS=$DEFAULTIFS; unset i; unset usr; unset disp; unset usrhome; unset actv; unset sssnarr; unset sssn
}

backgroundnotify(){ while : ; do
    getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
        if [ -f "${s_home[$i]}/.cache/xs/logonnotify" ]; then
            iconwarn; sleep 5; sendmsg "${s_usr[$i]}" "${s_disp[$i]}" \
                "System is updating (please do not turn off the computer)\nDetails: $log_f"
            rm -f "${s_home[$i]}/.cache/xs/logonnotify"
        fi; i=$(($i+1)); sleep 2
    done
done; }

userlogon(){
    sleep 5; if [ ! -d "$HOME/.cache/xs" ]; then mkdir -p "$HOME/.cache/xs"; fi
    if [ ! -f "$log_f" ]; then if [[ `ls "${log_d}" | grep -F "auto-update.log_" 2>/dev/null` ]]; then
        iconcritical; notify-send -i $icon XS-AutoUpdate -u critical \
            "Kernel and/or drivers were updated. Please restart your computer to finish"
    fi; else echo "This is a temporary file. It will be removed automatically" > "~/.cache/xs/logonnotify"; fi
}


#---Init Config---

#Init Defaults

typeset -A flag_a

typeset -A conf_a; conf_a=(
    [aur_1helper_str]="auto"
    [aur_update_freq]=3
    [aur_devel_freq]=6
    [cln_1enable_bool]=$ctrue
    [cln_aurpkg_bool]=$ctrue
    [cln_aurbuild_bool]=$ctrue
    [cln_orphan_bool]=$ctrue
    [cln_paccache_num]=0
    [flatpak_update_freq]=3
    [notify_1enable_bool]=$ctrue
    [notify_lastmsg_num]=20
    [notify_errors_bool]=$ctrue
    [notify_vsn_bool]=$cfalse
    [main_ignorepkgs_str]=""
    [main_logdir_str]="/var/log/xs"
    [main_perstdir_str]=""
    [main_country_str]=""
    [main_testsite_str]="www.google.com"
    [self_1enable_bool]=$ctrue
    [self_branch_str]="stable"
    [update_downgrades_bool]=$ctrue
    [update_keys_freq]=30
    [update_mirrors_freq]=0
    [reboot_1enable_bool]=$cfalse
    [reboot_delayiflogin_bool]=$ctrue
    [reboot_delay_num]=120
    [reboot_notifyrep_num]=10
    [reboot_ignoreusers_str]="nobody lightdm sddm gdm"
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
)

shopt -s extglob # needed for validconf
validconf=@($(echo "${!conf_a[*]}"|sed "s/ /|/g"))

conf_int0="notify_lastmsg_num reboot_delay_num reboot_notifyrep_num"
conf_intn1="cln_paccache_num aur_update_freq aur_devel_freq flatpak_update_freq update_keys_freq update_mirrors_freq"
conf_legacy="bool_detectErrors bool_Downgrades bool_notifyMe bool_updateFlatpak bool_updateKeys str_cleanLevel \
    str_ignorePackages str_log_d str_mirrorCountry str_testSite aur_devel_bool flatpak_1enable_bool"

#Load external config
#Basic config validation

if [[ -f "$xs_autoupdate_conf" ]]; then
    while read line; do
        line=$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)
        if echo "$line" | grep -F '=' &>/dev/null; then
            varname=$(echo "$line" | cut -d '=' -f 1)
            case $varname in
                $validconf) ;;
                *) echo "$varname"|grep -F "zflag:" >/dev/null || continue
            esac
            line=$(echo "$line" | cut -d '=' -f 2-)
            if [[ ! "$line" = "" ]]; then
                #validate boolean
                echo "$varname" | grep -F "bool" >/dev/null && if [[ ! ( "$line" = "$ctrue" || \
                    "$line" = "$cfalse" ) ]]; then continue; fi
                #validate numbers
                if echo "$varname" | grep "num" >/dev/null; then 
                    if [[ ! "$line" = "0" ]]; then let "line += 0"
                    [[ "$line" = "0" ]] && continue; fi; fi
                #validate integers 0+
                if echo "$conf_int0" | grep "$varname" >/dev/null; then 
                    if [[ "$line" -lt "0" ]]; then continue; fi; fi
                #validate integers -1+
                if echo "$conf_intn1" | grep "$varname" >/dev/null; then 
                    if [[ "$line" -lt "-1" ]]; then continue; fi; fi
                #validate reboot_notifyrep_num
                if [[ "$varname" = "reboot_notifyrep_num" ]]; then
                    if [[ "$line" -gt "${conf_a[reboot_delay_num]}" ]]; then
                        line=${conf_a[reboot_delay_num]}; fi
                    if [[ "$line" = "0" ]]; then
                        line=1; fi
                fi
                #validate aur_helper_str
                if [[ "$varname" = "aur_helper_str" ]]; then case "$line" in
                        auto|none|all|pikaur|apacman) ;;
                        *) continue
                esac; fi
                #validate self_branch_str
                if [[ "$varname" = "self_branch_str" ]]; then case "$line" in
                        stable|beta) ;;
                        *) continue
                esac; fi

                conf_a[$varname]=$line
                echo "$varname" | grep -F "zflag:" >/dev/null && \
                    flag_a[$(echo "$varname" | cut -d ':' -f 2)]="${conf_a[$varname]}"

            fi
        fi
    done < "$xs_autoupdate_conf"; unset line; unset varname
fi
unset validconf; shopt -u extglob

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

DEFAULTIFS=$IFS; IFS=$' '
for i in $(sort <<< "$conf_legacy"); do
	unset conf_a[$i]
done; IFS=$DEFAULTIFS


log_d="${conf_a[main_logdir_str]}"; log_f="${log_d}/auto-update.log"

if [ "${conf_a[main_perstdir_str]}" = "" ]; then perst_d="$log_d";
else perst_d="${conf_a[main_perstdir_str]}"; fi
perst_f="${perst_d}/auto-update_persist.dat"

#Load persistent data
typeset -A perst_a; perst_a=(
    [last_aur_update]="20000101"
    [last_aurdev_update]="20000101"
    [last_flatpak_update]="20000101"
    [last_keys_update]="20000101"
    [last_mirrors_update]="20000101"
)

shopt -s extglob # needed for validconf
validconf=@($(echo "${!perst_a[*]}"|sed "s/ /|/g"))


if [[ -f "$perst_f" ]]; then
    while read line; do
        line=$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)
        if echo "$line" | grep -F '=' &>/dev/null; then
            varname=$(echo "$line" | cut -d '=' -f 1)
            case $varname in
                $validconf) ;;
                *) continue
            esac
            line=$(echo "$line" | cut -d '=' -f 2-)
            if [[ ! "$line" = "" ]]; then
                #validate timestamp
                let "line += 0"; [[ "$line" -lt "20000101" ]] && continue
                perst_a[$varname]=$line
            fi
        fi
    done < "$perst_f"; unset line; unset varname
fi

unset validconf; shopt -u extglob


#---Main---

[[ "${conf_a[notify_vsn_bool]}" = "$ctrue" ]] && notifyvsn="[$vsn]\n"


#Start Sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi

#Init log dir, check for other running instances, start notifier
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then conf_a[main_logdir_str]="/var/log/xs"; fi
mkdir -p "${conf_a[main_logdir_str]}"; if [ ! -d "${conf_a[main_logdir_str]}" ]; then
    echo "Critical error: could not create log directory"; sleep 10; exit; fi
if [ ! -f "$log_f" ]; then echo "init">$log_f; fi
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then exit 0; fi #Only 1 main instance allowed
conf_export
perst_export
if [ $# -eq 0 ]; then
    echo "`date` - XS-Update $vsndsp starting..." |tee $log_f
    troublem "Config file: $xs_autoupdate_conf"
    "$0" "XS"& exit 0
fi

#Wait up to 5 minutes for network
trouble "Waiting for network..."
waiting=1;waited=0; while [ $waiting = 1 ]; do
    test_online && waiting=0
    if [ $waiting = 1 ]; then
        if [ $waited -ge 60 ]; then exit; fi
        sleep 5; waited=$(($waited+1))
    fi
done; unset waiting; unset waited

sleep 8 # In case connection just established

#Check for updates for self
if [[ "${conf_a[self_1enable_bool]}" = "$ctrue" ]]; then
    trouble "Checking for self-updates [branch: ${conf_a[self_branch_str]}]..."
    vsn_new=""; hash_new=""
    vsn_new="$(curl "https://raw.githubusercontent.com/lectrode/xs-update-manjaro/master/vsn_${conf_a[self_branch_str]}" | tr -cd '[:alnum:]+-.')"
    if [[ ! "$(echo $vsn_new | cut -d '+' -f 1)" = "`printf "$(echo $vsn_new | cut -d '+' -f 1)\n$vsn" | sort -V | head -n1`" ]]; then
        hash_new=$(curl "https://raw.githubusercontent.com/lectrode/xs-update-manjaro/${vsn_new}/hash_auto-update-sh" |tr -cd [:alnum:])
        if [ "${#hash_new}" = "64" ]; then
            wget "https://raw.githubusercontent.com/lectrode/xs-update-manjaro/${vsn_new}/auto-update.sh" -O "/tmp/xs-auto-update.sh"
            if [[ "$(sha256sum '/tmp/xs-auto-update.sh' |cut -d ' ' -f 1 |tr -cd [:alnum:])" = "$hash_new" ]]; then
                troublem "Updating script to $vsn_new..."
                mv -f '/tmp/xs-auto-update.sh' "$0"
                chmod +x "$0"; "$0" "XS"& exit 0
            fi; [[ -f "/tmp/xs-auto-update.sh" ]] && rm -f "/tmp/xs-auto-update.sh"
        fi;
    fi; unset vsn_new; unset hash_new
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
done;  unset waiting; unset waited; unset isRunning

#remove .lck file (pacman is not running at this point)
if [ -f /var/lib/pacman/db.lck ]; then rm -f /var/lib/pacman/db.lck; fi

#init main script and background notifications
trouble "Init vars and notifier..."
pacmirArgs="--geoip"
[[ "${conf_a[main_country_str]}" = "" ]] || pacmirArgs="-c ${conf_a[main_country_str]}"
[[ "${conf_a[main_ignorepkgs_str]}" = "" ]] || pacignore="--ignore ${conf_a[main_ignorepkgs_str]}"
[[ "${conf_a[update_downgrades_bool]}" = "$ctrue" ]] && pacdown="u"

getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
    mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
    chown -R ${s_usr[$i]} "${s_home[$i]}/.cache/xs"; fi; i=$(($i+1)); done
"$0" "backnotify"& bkntfypid=$!

#Check for, download, and install main updates
pacclean

if perst_isneeded "${conf_a[update_mirrors_freq]}" "${perst_a[last_mirrors_update]}"; then
    trouble "Updating Mirrors..."
    pacman-mirrors $pacmirArgs 2>&1 |sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |tee -a $log_f
    err_mirrors=${PIPESTATUS[0]}; if [[ $err_mirrors -eq 0 ]]; then 
        perst_update "last_mirrors_update"; else trouble "ERR: pacman-mirrors exited with code $err_mirrors"; fi
fi

if perst_isneeded "${conf_a[update_keys_freq]}" "${perst_a[last_keys_update]}"; then
    trouble "Refreshing keys..."; pacman-key --refresh-keys  2>&1 |tee -a $log_f
    err_keys=${PIPESTATUS[0]}; if [[ $err_keys -eq 0 ]]; then
        perst_update "last_keys_update"; else trouble "ERR: pacman-key exited with code $err_keys"; fi
fi

trouble "Updating system packages..."
pacman -Syy --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system 2>&1 |tee -a $log_f
err_sys=${PIPESTATUS[0]}; if [[ $err_sys -ne 0 ]]; then trouble "ERR: pacman exited with code $err_sys"; fi

sync; trouble "Updating packages from main repos..."
pacman -Su$pacdown --needed --noconfirm $pacignore 2>&1 |tee -a $log_f
err_repo=${PIPESTATUS[0]}; if [[ $err_repo -ne 0 ]]; then trouble "ERR: pacman exited with code $err_repo"; fi


#Select supported/configured AUR Helper(s)
use_apacman=1; use_pikaur=1
if echo "${conf_a[aur_1helper_str]}" | grep "none" >/dev/null; then conf_a[aur_1helper_str]="none"; use_apacman=0; use_pikaur=0; fi
echo "${conf_a[aur_1helper_str]}" | grep 'all\|auto\|pikaur' >/dev/null || use_pikaur=0
echo "${conf_a[aur_1helper_str]}" | grep 'all\|auto\|apacman' >/dev/null || use_apacman=0
if ! perst_isneeded "${conf_a[aur_update_freq]}" "${perst_a[last_aur_update]}";  then use_apacman=0; use_pikaur=0; fi

if [ "$use_pikaur" = "1" ]; then if ! type pikaur >/dev/null 2>&1; then
    use_pikaur=0
    if echo "${conf_a[aur_1helper_str]}" | grep 'pikaur' >/dev/null; then
        trouble "Warning: AURHelper: pikaur specified but not found..."
    fi
fi; fi

if [ "$use_apacman" = "1" ]; then if ! type apacman >/dev/null 2>&1; then
    use_apacman=0
    if echo "${conf_a[aur_1helper_str]}" | grep 'apacman' >/dev/null; then
        trouble "Warning: AURHelper: apacman specified but not found..."
    fi
fi; fi

if echo "${conf_a[aur_1helper_str]}" | grep 'auto' >/dev/null; then
    if [ "$use_pikaur" = "1" ]; then conf_a[aur_1helper_str]="auto"; use_apacman=0; fi; fi

#Update AUR packages

if [[ "$use_pikaur" = "1" ]]; then
    if [[ ! "${#flag_a[@]}" = "0" ]]; then
        trouble "Updating AUR packages with custom flags [pikaur]..."
        for i in ${!flag_a[*]}; do
            if ! test_online; then trouble "Not online - skipping pikaur command"; break; fi
            pacman -Q $(echo "$i" | tr ',' ' ') >/dev/null 2>&1 && \
                pikaur -S --needed --noconfirm --noprogressbar --mflags=${flag_a[$i]} $(echo "$i" | tr ',' ' ') 2>&1 |tee -a $log_f
                let "err_aur=err_aur+${PIPESTATUS[0]}"
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

if [[ "$use_apacman" = "1" ]]; then
    # Workaround apacman script crash ( https://github.com/lectrode/xs-update-manjaro/issues/2 )
    dummystty="/tmp/xs-dummy/stty"
    mkdir `dirname $dummystty`
    echo '#!/bin/sh' >$dummystty
    echo "echo 15" >>$dummystty
    chmod +x $dummystty
    export PATH=`dirname $dummystty`:$PATH

    trouble "Updating AUR packages [apacman]..."
    apacman -Su$pacdown --auronly --needed --noconfirm $pacignore 2>&1 |\
        sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |grep -Fv "%" |tee -a $log_f
    err_aur=${PIPESTATUS[0]}; if [[ $err_aur -eq 0 ]]; then 
        perst_update "last_aur_update"; else trouble "ERR: apacman exited with error"; fi
    if [ -d "`dirname $dummystty`" ]; then rm -rf "`dirname $dummystty`"; fi
fi

#Remove orphan packages, cleanup
if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]]; then 
    if [[ "${conf_a[cln_orphan_bool]}" = "$ctrue" ]]; then
        if [[ ! "$(pacman -Qtdq)" = "" ]]; then
            trouble "Removing orphan packages..."
            pacman -Rnsc $(pacman -Qtdq) --noconfirm  2>&1 |tee -a $log_f
            err_orphan=${PIPESTATUS[0]}; [[ $err_orphan -gt 0 ]] && trouble "ERR: pacman exited with error code $err_orphan"
        fi
    fi
fi
pacclean

#Update Flatpak
if perst_isneeded "${conf_a[flatpak_update_freq]}" "${perst_a[last_flatpak_update]}"; then
    if type flatpak >/dev/null 2>&1; then
        trouble "Updating flatpak..."
        flatpak update -y | grep -Fv "[" 2>&1 |tee -a $log_f
        err_fpak=${PIPESTATUS[0]}; if [[ $err_fpak -eq 0 ]]; then
            perst_update "last_flatpak_update"; else trouble "ERR: flatpak exited with error code $err_fpak"; fi
    fi
fi

#Finish
trouble "Update completed, final notifications and cleanup..."
kill $bkntfypid

msg="System update finished"
grep "Total Installed Size:\|new signatures:\|Total Removed Size:" $log_f >/dev/null || msg="$msg; no changes made"

if [ "${conf_a[notify_errors_bool]}" = "$ctrue" ]; then 
    trouble "error codes: [mirrors:$err_mirrors][sys:$err_sys][keys:$err_keys][repo:$err_repo][aur:$err_aur][fpak:$err_fpak][orphan:$err_orphan]"
    [[ "$err_mirrors" -gt 0 ]] && errmsg="\n-Mirrors failed to update"
    [[ "$err_sys" -gt 0 ]] && errmsg="$errmsg \n-System packages failed to update"
    [[ "$err_keys" -gt 0 ]] && errmsg="$errmsg \n-Security signatures failed to update"
    [[ "$err_repo" -gt 0 ]] && errmsg="$errmsg \n-Packages from main repos failed to update"
    [[ "$err_aur" -gt 0 ]] && errmsg="$errmsg \n-Packages from AUR failed to update"
    [[ "$err_fpak" -gt 0 ]] && errmsg="$errmsg \n-Packages from Flatpak failed to update"
    [[ "$err_orphan" -gt 0 ]] && errmsg="$errmsg \n-Failed to remove orphan packages"
    [[ "$errmsg" = "" ]] || msg="$msg \n\nSome update tasks encountered errors:$errmsg"
fi

if [ ! "$msg" = "System update finished; no changes made" ]; then 
    [[ "$msg" = "System update finished" ]] || msg="$msg\n"
    msg="$msg\nDetails: $log_f"
fi

normcrit=norm; grep -Ei "(up|down)(grad|dat)ing (linux[0-9]{2,3}|systemd)(\.|-| )" $log_f >/dev/null && normcrit=crit
if [[ "$normcrit" = "norm" ]]; then finalmsg_normal; else finalmsg_critical; fi
trouble "XS-done"; sync; disown -a; sleep 1; systemctl stop xs-autoupdate.service >/dev/null 2>&1; exit 0


