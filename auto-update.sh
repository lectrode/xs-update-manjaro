#!/bin/bash
#Auto Update v1.1 2016-08-28 For Arch Linux (Manjaro Xfce) by Lectrode
#-Downloads and Installs new updates
#-Depends: apacman, xfce4-notifyd, cut, grep, ping, su
#This assumes all users have profile folders stored in /home

debgn=+x; #-x =debugging, +x =no debugging
set $debgn

logdir="/var/log/XS"; logfile=$logdir/auto-update.log; mkdir -p "$logdir";

pacclean(){ 
paccache -rvk0;
rm -rf /var/cache/apacman/pkg/*;
#paccache -rvk3;
}

#Notification Functions
killmsg(){ killall xfce4-notifyd; }
iconnormal(){ icon=ElectrodeXS; }
iconwarn(){ icon=software-update-urgent-symbolic; }
iconcritical(){ icon=software-update-urgent; }
sendmsg(){ DISPLAY=$2 su $1 -c "notify-send -i $icon XS-AutoUpdate -u critical \"$3\""; }
sendall(){ getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do sendmsg "${s_usr[$i]}" "${s_disp[$i]}" "$1"; i=$(($i+1)); done; unset i; }
finalmsg_normal(){ killmsg; iconnormal; sendall "$msg"; sleep 20; killmsg; }
finalmsg_critical(){ killmsg; iconcritical; sendall "Kernel and/or drivers were updated. A restart is highly advised"; mv -f "$logfile" "${logfile}_`date -I`"; logfile=${logfile}_`date -I`; }

getsessions(){ DEFAULTIFS=$IFS; CUSTOMIFS=$(echo -en "\n\b"); IFS=$CUSTOMIFS;
i=0; while [ $i -lt ${#s_usr[@]} ]; do unset s_usr[$i]; unset s_disp[$i]; i=$(($i+1)); done;
i=0; for sssn in `loginctl list-sessions --no-legend`; do IFS=' '; sssnarr=($sssn);
actv=$(loginctl show-session -p Active ${sssnarr[0]}|cut -d '=' -f 2);
[[ "$actv" = "yes" ]] || continue;
usr=$(loginctl show-session -p Name ${sssnarr[0]}|cut -d '=' -f 2);
disp=$(loginctl show-session -p Display ${sssnarr[0]}|cut -d '=' -f 2);
[[  ${usr-x} && ${disp-x} ]] || continue;
s_usr[$i]=$usr; s_disp[$i]=$disp; i=$(($i+1)); IFS=$CUSTOMIFS; done;
IFS=$DEFAULTIFS; unset i; unset usr; unset disp; unset actv; unset sssnarr; unset sssn; }

backgroundnotify(){ while : ; do getsessions;
i=0; while [ $i -lt ${#s_usr[@]} ]; do if [ -f "/home/${s_usr[$i]}/.cache/XS/logonnotify" ]; then
iconwarn; sendmsg "${s_usr[$i]}" "${s_disp[$i]}" "System is updating (please do not turn off the computer)\nDetails: $logfile"; 
rm -f "/home/${s_usr[$i]}/.cache/XS/logonnotify"; fi; i=$(($i+1)); sleep 2; done; done; };

userlogon(){ if [ ! -d "/home/$USER/.cache/XS" ]; then mkdir -p "/home/$USER/.cache/XS"; fi;
echo "This is a temporary file. It will be removed automatically" > /home/$USER/.cache/XS/logonnotify; 
if [ ! -f "$logfile" ]; then if [ -f "${logfile}_lastkernel" ]; then
iconcritical; notify-send -i $icon XS-AutoUpdate -u critical "Kernel and/or drivers were updated. A restart is highly advised"; fi; fi; }

checkwifi(){ if [ -d /home/.wifi ]; then
rm -rf /etc/NetworkManager/system-connections;
ln -s /home/.wifi /etc/NetworkManager/system-connections; fi; }

#Start Sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi;
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi;

#Network and misc checks
if [ ! -f "$logfile" ]; then echo "init">$logfile; fi;
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then exit 0; fi; #Only 1 main instance allowed
if [ $# -eq 0 ]; then "$0" "XS"& exit 0; fi;                       #Run in background
checkwifi; waiting=1;waited=0; while [ $waiting = 1 ]
do ping -c 1 www.google.com && waiting=0;
if [ $waiting = 1 ]; then if [ $waited -ge 60 ]; then exit; fi;    #Wait up to 5 minutes for network
sleep 5; waited=$(($waited+1)); fi; done;
sleep 8; pgrep apacman && exit;

#Start log and background notifications
echo "init">$logfile; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "/home/${s_usr[$i]}/.cache" ]; then
mkdir -p "/home/${s_usr[$i]}/.cache/XS"; echo "tmp" > /home/${s_usr[$i]}/.cache/XS/logonnotify;
chown -R ${s_usr[$i]} "/home/${s_usr[$i]}/.cache/XS"; fi; i=$(($i+1)); done;
"$0" "backnotify"& bkntfypid=$!;

#Check for, download, and install updates; Remove obsolete packages
(pacclean; pacman-mirrors -g -c United_States;)  2>&1 |tee -a $logfile;
sudo pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system 2>&1 |tee -a $logfile;
(pacman-key --refresh-keys; pacman-optimize; sync;)  2>&1 |tee -a $logfile;
apacman -Syyuu --needed --noconfirm 2>&1 |tee -a $logfile
(pacman -Rnsc $(pacman -Qtdq) --noconfirm; pacclean;)  2>&1 |tee -a $logfile
#sleep 5;

#Finish
checkwifi; kill $bkntfypid;
msg="System update finished"; grep "Total Installed Size:" $logfile && msg="$msg \nPackages successfully updated"
grep "new signatures:" $logfile && msg="$msg \nSecurity signatures updated"
grep "Total Removed Size:" $logfile && msg="$msg \nObsolete packages removed"
if [ ! "$msg" = "System update finished" ]; then msg="$msg \nDetails: $logfile"; fi;
if [ "$msg" = "System update finished" ]; then msg="System up-to-date, no changes made"; fi;
normcrit=norm; grep -v "warning" $logfile |grep -v "removed"|grep -v "tor-browser"|grep -E "linux[0-9]{2,3}" && normcrit=crit
[[ "$normcrit" = "norm" ]] && finalmsg_normal; [[ "$normcrit" = "crit" ]] && finalmsg_critical;
echo "XS-done">>$logfile; exit 0;
