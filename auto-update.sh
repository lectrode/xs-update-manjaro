#!/bin/bash
#Auto Update v2.05 2017-11-16 For Manjaro Xfce by Lectrode
#-Downloads and Installs new updates
#-Depends: pacman, paccache, xfce4-notifyd, cut, grep, ping, su
#-Optional Depends: apacman
true=0; false=1; ctrue=1; cfalse=0;

debgn=+x; # -x =debugging | +x =no debugging
set $debgn


#---Load/Generate config---
conf_f='/etc/xs/auto-update.conf'
typeset -A conf_a; conf_a=(
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

if [ -f $conf_f ]; then while read line; do
    if echo $line | grep -F = &>/dev/null
    then
        varname=$(echo "$line" | cut -d '=' -f 1)
        line=$(echo "$line" | cut -d '=' -f 2-)
        line=$(echo "$line" | cut -d ';' -f 1)
        [[ "$line" = "" ]] || conf_a[$varname]=$line
    fi
done < "$conf_f"; unset line; unset varname; fi

exportconf(){
if [ ! -d `dirname $conf_f` ]; then mkdir `dirname $conf_f`; fi
echo '#Config for XS-AutoUpdate' | sudo tee "$conf_f"
echo '#' | sudo tee -a "$conf_f"
echo '#NOTES:' | sudo tee -a "$conf_f"
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
for i in ${!conf_a[*]}; do
	echo "$i=${conf_a[$i]}" | sudo tee -a "$conf_f"
done;
}

#--------------------------

pacclean(){ 
[[ "${conf_a[str_cleanLevel]}" = "high" ]] && paccache -rvk0
[[ "${conf_a[str_cleanLevel]}" = "low" ]]  && paccache -rvk2
[[ "${conf_a[str_cleanLevel]}" = "off" ]]  || (if [ -d /var/cache/apacman/pkg ]; then rm -rf /var/cache/apacman/pkg/*; fi)
}

#Notification Functions
killmsg(){ if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then killall xfce4-notifyd; fi; }
iconnormal(){ icon=ElectrodeXS; }
iconwarn(){ icon=important; }
iconcritical(){ icon=system-shutdown; }
sendmsg(){ if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then DISPLAY=$2 su $1 -c "dbus-launch notify-send -i $icon XS-AutoUpdate -u critical \"$3\""; fi; }
sendall(){ if [ "${conf_a[bool_notifyMe]}" = "$ctrue" ]; then getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do sendmsg "${s_usr[$i]}" "${s_disp[$i]}" "$1"; i=$(($i+1)); done; unset i; fi; }
finalmsg_normal(){ killmsg; iconnormal; sendall "$msg"; sleep 20; killmsg; }
finalmsg_critical(){ killmsg; iconcritical; sendall "Kernel and/or drivers were updated. A restart is highly advised"; mv -f "$log_f" "${log_f}_`date -I`"; log_f=${log_f}_`date -I`; }

getsessions(){ DEFAULTIFS=$IFS; CUSTOMIFS=$(echo -en "\n\b"); IFS=$CUSTOMIFS
i=0; while [ $i -lt ${#s_usr[@]} ]; do unset s_usr[$i]; unset s_disp[$i]; unset s_home[$i]; i=$(($i+1)); done
i=0; for sssn in `loginctl list-sessions --no-legend`; do IFS=' '; sssnarr=($sssn)
actv=$(loginctl show-session -p Active ${sssnarr[0]}|cut -d '=' -f 2)
[[ "$actv" = "yes" ]] || continue
usr=$(loginctl show-session -p Name ${sssnarr[0]}|cut -d '=' -f 2)
disp=$(loginctl show-session -p Display ${sssnarr[0]}|cut -d '=' -f 2)
usrhome=$(getent passwd "$usr"|cut -d: -f6) #alt: eval echo "~$usr"
[[  ${usr-x} && ${disp-x} && ${usrhome-x} ]] || continue
s_usr[$i]=$usr; s_disp[$i]=$disp; s_home[$i]=$usrhome; i=$(($i+1)); IFS=$CUSTOMIFS; done
IFS=$DEFAULTIFS; unset i; unset usr; unset disp; unset usrhome; unset actv; unset sssnarr; unset sssn; }

backgroundnotify(){ while : ; do getsessions;
i=0; while [ $i -lt ${#s_usr[@]} ]; do if [ -f "${s_home[$i]}/.cache/xs/logonnotify" ]; then
iconwarn; sendmsg "${s_usr[$i]}" "${s_disp[$i]}" "System is updating (please do not turn off the computer)\nDetails: $log_f"
rm -f "${s_home[$i]}/.cache/xs/logonnotify"; fi; i=$(($i+1)); sleep 2; done; done; }

userlogon(){ if [ ! -d "$HOME/.cache/xs" ]; then mkdir -p "$HOME/.cache/xs"; fi
echo "This is a temporary file. It will be removed automatically" > "$HOME/.cache/xs/logonnotify"
if [ ! -f "$log_f" ]; then if [ -f "${log_f}_lastkernel" ]; then
iconcritical; notify-send -i $icon XS-AutoUpdate -u critical "Kernel and/or drivers were updated. A restart is highly advised"; fi; fi; }


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
if [ $# -eq 0 ]; then "$0" "XS"& exit 0; fi                       #Run in background

#Wait up to 5 minutes for network
waiting=1;waited=0; while [ $waiting = 1 ]
do ping -c 1 "${conf_a[str_testSite]}" && waiting=0
if [ $waiting = 1 ]; then if [ $waited -ge 60 ]; then exit; fi
sleep 5; waited=$(($waited+1)); fi; done; unset waiting; unset waited

#use apacman if available
sleep 8; pacman=apacman; type apacman || pacman=pacman

#wait up to 5 minutes for running instances of pacman/apacman
waiting=1;waited=0; while [ $waiting = 1 ]
do isRunning=0; pgrep pacman && isRunning=1
pgrep apacman && isRunning=1; [[ $isRunning = 1 ]] || waiting=0
if [ $waiting = 1 ]; then if [ $waited -ge 60 ]; then exit; fi
sleep 5; waited=$(($waited+1)); fi; done;  unset waiting; unset waited; unset isRunning

#remove .lck file (pacman is not running at this point)
if [ -f /var/lib/pacman/db.lck ]; then rm -f /var/lib/pacman/db.lck; fi

#init main script and background notifications
pacmirArgs="--geoip"
[[ "${conf_a[str_mirrorCountry]}" = "" ]] || pacmirArgs="-c ${conf_a[str_mirrorCountry]}"
[[ "${conf_a[str_ignorePackages]}" = "" ]] || pacignore="--ignore ${conf_a[str_ignorePackages]}"
[[ "${conf_a[bool_Downgrades]}" = "$ctrue" ]] && pacdown=u
echo "init">$log_f; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
chown -R ${s_usr[$i]} "${s_home[$i]}/.cache/xs"; fi; i=$(($i+1)); done
"$0" "backnotify"& bkntfypid=$!

# Workaround apacman script crash ( https://github.com/lectrode/xs-update-manjaro/issues/2 )
if [ "$pacman" = "apacman" ]; then
dummystty="/tmp/xs-dummy/stty"
mkdir `dirname $dummystty`
echo '#!/bin/sh' >$dummystty
echo "echo 15" >>$dummystty
chmod +x $dummystty
export PATH=`dirname $dummystty`:$PATH
fi

#Check for, download, and install updates; Remove obsolete packages
(pacclean; pacman-mirrors $pacmirArgs)  2>&1 |tee -a $log_f
pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system 2>&1 |tee -a $log_f
[[ "${conf_a[bool_updateKeys]}" = "$ctrue" ]] && (pacman-key --refresh-keys; pacman-optimize; sync;)  2>&1 |tee -a $log_f
$pacman -Syyu$pacdown --needed --noconfirm $pacignore 2>&1 |tee -a $log_f
(pacman -Rnsc $(pacman -Qtdq) --noconfirm; pacclean;)  2>&1 |tee -a $log_f
[[ "${conf_a[bool_updateFlatpak]}" = "$ctrue" ]] && (type flatpak && flatpak update)  2>&1 |tee -a $log_f
#sleep 5;

#Finish
if [ -d "`dirname $dummystty`" ]; then rm -rf "`dirname $dummystty`"; fi
kill $bkntfypid; exportconf
msg="System update finished"; grep "Total Installed Size:" $log_f && msg="$msg \nPackages successfully updated"
grep "new signatures:" $log_f && msg="$msg \nSecurity signatures updated"
grep "Total Removed Size:" $log_f && msg="$msg \nObsolete packages removed"
if [ "${conf_a[bool_detectErrors]}" = "$ctrue" ]; then grep "error: failed " $log_f && msg="$msg \nSome packages encountered errors"; fi
if [ ! "$msg" = "System update finished" ]; then msg="$msg \nDetails: $log_f"; fi
if [ "$msg" = "System update finished" ]; then msg="System up-to-date, no changes made"; fi
normcrit=norm; grep -v "warning" $log_f |grep -v "removed"|grep -v "copying"|grep -v "Unresolvable"|grep -v "tor-browser"|grep -E "linux[0-9]{2,3}" && normcrit=crit
[[ "$normcrit" = "norm" ]] && finalmsg_normal; [[ "$normcrit" = "crit" ]] && finalmsg_critical
echo "XS-done">>$log_f; exit 0
