#!/bin/bash
#Auto Update For Manjaro Xfce by Lectrode
vsn="v3.0.0-dev"; vsndsp="$vsn 2018-09-03"
#-Downloads and Installs new updates
#-Depends: pacman, paccache, xfce4-notifyd, grep, ping
#-Optional Depends: pikaur, apacman (deprecated)
true=0; false=1; ctrue=1; cfalse=0;

debgn=+x; # -x =debugging | +x =no debugging
set $debgn


#---Load/Generate config---
conf_f='/etc/xs/auto-update.conf'
typeset -A flag_a
typeset -A conf_a; conf_a=(
    [aur_1helper_str]="auto"
    [aur_devel_bool]=$ctrue
    [notify_lastmsg_num]=20
    [bool_Downgrades]="$ctrue"
    [bool_detectErrors]=$ctrue
    [bool_updateKeys]=$ctrue
    [bool_updateFlatpak]=$ctrue
    [bool_notifyMe]=$ctrue
    [str_ignorePackages]=""
    [str_mirrorCountry]=""
    [str_testSite]="www.google.com"
    [str_cleanLevel]="high" #high, low, off
    [str_log_d]="/var/log/xs" )

if [ -f $conf_f ]; then
    while read line; do
        if ! echo ${line:0:1} | grep -E '#|;' >/dev/null; then
            if echo $line | grep -F = &>/dev/null; then
                varname=$(echo "$line" | cut -d '=' -f 1)
                line=$(echo "$line" | cut -d '=' -f 2-)
                line=$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)
                if [[ "$line" = "" ]]; then echo "$varname" | grep -F "num" >/dev/null && let "line += 0"; fi
                [[ "$line" = "" ]] || conf_a[$varname]=$line
                echo "$varname" | grep -F "zflag:" >/dev/null && \
                flag_a[$(echo "$varname" | cut -d ':' -f 2)]="${conf_a[$varname]}"
            fi
        fi
    done < "$conf_f"; unset line; unset varname
fi

exportconf(){
if [ ! -d `dirname $conf_f` ]; then mkdir `dirname $conf_f`; fi
echo '#Config for XS-AutoUpdate' | sudo tee "$conf_f"
echo '#' | sudo tee -a "$conf_f"
echo '#NOTES:' | sudo tee -a "$conf_f"
echo '#aur_1helper_str: Valid options are auto,none,all,pikaur,apacman' | sudo tee -a "$conf_f"
echo '#aur_devel_bool: Check for AUR devel package updates (requires pikaur AURHelper)' | sudo tee -a "$conf_f"
echo '#notify_lastmsg_num: Seconds before final normal notification expires (0=never)' | sudo tee -a "$conf_f"
echo '#bool_Downgrades: Directs pacman to downgrade package if remote is older than local' | sudo tee -a "$conf_f"
echo '#bool_detectErrors: Include possible errors in notifications' | sudo tee -a "$conf_f"
echo '#bool_updateKeys: Check for security signature/key updates' | sudo tee -a "$conf_f"
echo '#bool_updateFlatpak: Check for Flatpak package updates' | sudo tee -a "$conf_f"
echo '#bool_notifyMe: Enable/Disable nofications' | sudo tee -a "$conf_f"
echo '#str_cleanLevel: high, low, or off. how much cleaning is done before/after update' | sudo tee -a "$conf_f"
echo '#str_ignorePackages: list of packages to ignore separated by spaces (in addition to pacman.conf)' | sudo tee -a "$conf_f"
echo '#str_mirrorCountry: Countries separated by commas from which to pull updates. Default is automatic (geoip)' | sudo tee -a "$conf_f"
echo '#str_testSite: url (without protocol) used to test internet connection' | sudo tee -a "$conf_f"
echo '#str_log_d: path to the log directory' | sudo tee -a "$conf_f"
echo '#' | sudo tee -a "$conf_f"
echo '#You can also specify makepkg flags for specific AUR packages (requires pikaur AURHelper):' | sudo tee -a "$conf_f"
echo '#zflag:packagename1,packagename2=--flag1,--flag2,--flag3' | sudo tee -a "$conf_f"
echo '#' | sudo tee -a "$conf_f"
DEFAULTIFS=$IFS; IFS=$'\n'
for i in $(sort <<< "${!conf_a[*]}"); do
	echo "$i=${conf_a[$i]}" | sudo tee -a "$conf_f"
done; IFS=$DEFAULTIFS
}

#--------------------------

trouble(){ (echo;echo "#XS# `date` - $@";echo) |tee -a $log_f; }

pacclean(){ 
if [ ! "${conf_a[str_cleanLevel]}" = "off" ]; then
    trouble "Cleaning package cache..."
    if [ -d /var/cache/apacman/pkg ]; then rm -rf /var/cache/apacman/pkg/*; fi
    if [ -d /var/cache/pikaur/pkg ]; then rm -rf /var/cache/pikaur/pkg/*; fi
    [[ "${conf_a[str_cleanLevel]}" = "low" ]]  && paccache -rvk2
    if [ "${conf_a[str_cleanLevel]}" = "high" ]; then
        paccache -rvk0; [[ -d /var/cache/pikaur ]] && rm -rf /var/cache/pikaur/*; fi
fi; }

#Notification Functions

killmsg(){ if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then killall xfce4-notifyd; fi; }
iconnormal(){ icon=ElectrodeXS; }
iconwarn(){ icon=important; }
iconcritical(){ icon=system-shutdown; }

sendmsg(){
    if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then
        DISPLAY=$2 su $1 -c "dbus-launch notify-send -i $icon XS-AutoUpdate -u critical \"$3\"" & fi
}

sendall(){
    if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then
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
    killmsg; iconcritical; sendall "Kernel and/or drivers were updated. Please restart your computer to finish"
    mv -f "$log_f" "${log_f}_`date -I`"; log_f=${log_f}_`date -I`
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


#---Init Main---

#Define Log file
[[ "${conf_a[str_log_d]}" = "" ]] && conf_a[str_log_d]="/var/log/xs"
log_d="${conf_a[str_log_d]}"; log_f="${log_d}/auto-update.log"

#Start Sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi

#Init log dir, check for other running instances, start notifier
mkdir -p "$log_d"; if [ ! -f "$log_f" ]; then echo "init">$log_f; fi
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then exit 0; fi #Only 1 main instance allowed
if [ $# -eq 0 ]; then echo "`date` - XS-Update $vsndsp starting..." |tee $log_f; "$0" "XS"& exit 0; fi #Run in background

#Wait up to 5 minutes for network
trouble "Waiting for network..."
waiting=1;waited=0; while [ $waiting = 1 ]; do
    ping -c 1 "${conf_a[str_testSite]}" >/dev/null && waiting=0
    if [ $waiting = 1 ]; then
        if [ $waited -ge 60 ]; then exit; fi
        sleep 5; waited=$(($waited+1))
    fi
done; unset waiting; unset waited


sleep 8 # In case connection just established

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
[[ "${conf_a[str_mirrorCountry]}" = "" ]] || pacmirArgs="-c ${conf_a[str_mirrorCountry]}"
[[ "${conf_a[str_ignorePackages]}" = "" ]] || pacignore="--ignore ${conf_a[str_ignorePackages]}"
[[ "${conf_a[bool_Downgrades]}" = "$ctrue" ]] && pacdown=u
[[ "${conf_a[aur_devel_bool]}" = "$ctrue" ]] && devel=--devel
getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
    mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
    chown -R ${s_usr[$i]} "${s_home[$i]}/.cache/xs"; fi; i=$(($i+1)); done
"$0" "backnotify"& bkntfypid=$!

#Check for, download, and install main updates
pacclean
trouble "Updating Mirrors..."
pacman-mirrors $pacmirArgs 2>&1 |sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |tee -a $log_f

trouble "Updating key packages..."
pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system 2>&1 |tee -a $log_f

if [[ "${conf_a[bool_updateKeys]}" = "$ctrue" ]]; then
    trouble "Refreshing keys..."; (pacman-key --refresh-keys; sync;)  2>&1 |tee -a $log_f; fi

trouble "Updating packages from main repos..."
pacman -Syyu$pacdown --needed --noconfirm $pacignore 2>&1 |tee -a $log_f


#Select supported/configured AUR Helper(s)
use_apacman=1; use_pikaur=1
if echo "${conf_a[aur_1helper_str]}" | grep "none" >/dev/null; then conf_a[aur_1helper_str]="none"; use_apacman=0; use_pikaur=0; fi
echo "${conf_a[aur_1helper_str]}" | grep 'all\|auto\|pikaur' >/dev/null || use_pikaur=0
echo "${conf_a[aur_1helper_str]}" | grep 'all\|auto\|apacman' >/dev/null || use_apacman=0

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
    if [[ ! "${#flag_a}" = "0" ]]; then
        trouble "Updating AUR packages with custom flags [pikaur]..."
        for i in ${!flag_a[*]}; do
            pacman -Q $(echo "$i" | tr ',' ' ') && \
                pikaur -S --needed --noconfirm --noprogressbar --mflags=${flag_a[$i]} $(echo "$i" | tr ',' ' ') 2>&1 |tee -a $log_f
        done
    fi
    trouble "Updating normal AUR packages [pikaur]..."
    pikaur -Sau$pacdown $devel --needed --noconfirm --noprogressbar $pacignore 2>&1 |tee -a $log_f
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
        sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176' |grep -v -F "%" |tee -a $log_f
    if [ -d "`dirname $dummystty`" ]; then rm -rf "`dirname $dummystty`"; fi
fi

#Remove orphan packages, cleanup
trouble "Removing orphan packages..."
pacman -Rnsc $(pacman -Qtdq) --noconfirm  2>&1 |tee -a $log_f
pacclean

#Update Flatpak
if [[ "${conf_a[bool_updateFlatpak]}" = "$ctrue" ]]; then if type flatpak >/dev/null 2>&1; then
    trouble "Updating flatpak..."
    flatpak update -y  2>&1 |tee -a $log_f
fi; fi

#Finish
trouble "Update completed, final notifications and cleanup..."
kill $bkntfypid; exportconf
msg="System update finished"; grep "Total Installed Size:" $log_f && msg="$msg \nPackages successfully updated"
grep "new signatures:" $log_f && msg="$msg \nSecurity signatures updated"
grep "Total Removed Size:" $log_f && msg="$msg \nObsolete packages removed"
if [ "${conf_a[bool_detectErrors]}" = "$ctrue" ]; then grep "error: failed " $log_f && msg="$msg \nSome packages encountered errors"; fi
if [ ! "$msg" = "System update finished" ]; then msg="$msg \nDetails: $log_f"; fi
if [ "$msg" = "System update finished" ]; then msg="System up-to-date, no changes made"; fi
normcrit=norm; grep "upgrading " $log_f |grep -v "tor-browser"|grep -E "linux[0-9]{2,3}" && normcrit=crit
[[ "$normcrit" = "norm" ]] && finalmsg_normal; [[ "$normcrit" = "crit" ]] && finalmsg_critical
trouble "XS-done"; sleep 2; disown -a; sleep 2; systemctl stop xs-autoupdate.service >/dev/null 2>&1; exit 0

