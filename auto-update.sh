#!/bin/sh
#Auto Update v0.2 2016-03-11 For Arch Linux (Manjaro Xfce) by Lectrode
#-Downloads and Installs new updates
#-Depends: apacman, xfce4-notifyd, awk, grep, ping, su
#This assumes all users have profile folders stored in /home

logdir="/var/log/XS"; logfile=$logdir/auto-update.log; mkdir -p "$logdir";
pacclean="pacman -Scc --noconfirm";
#pacclean="paccache -rvk3";

#Notification Functions
killmsg(){ killall xfce4-notifyd; }
getdisp(){ disp=$(who | awk -v user="$usr" '$1 == user && $2 ~ "^:" {print $2}'); };
sendmsg(){ getdisp; DISPLAY=$disp su $usr -c "notify-send -i ElectrodeXS XS-AutoUpdate -u critical \"$1\""; };
sendall(){ for usr in `ls /home|grep -v "Public"`; do sendmsg "$1"; done; }

backgroundnotify(){ while : ; do for usr in `ls /home|grep -v "Public"`;
do if [ -f "/home/$usr/.cache/XS/logonnotify" ]; then
sendmsg "System is updating (please do not turn off the computer)\nDetails: $logfile"; 
rm -f "/home/$usr/.cache/XS/logonnotify"; fi; sleep 2; done; done; };

userlogon(){ if [ ! -d "/home/$USER/.cache/XS" ]; then mkdir -p "/home/$USER/.cache/XS"; fi;
echo "This is a temporary file. It will be removed automatically" > /home/$USER/.cache/XS/logonnotify; }

#Start Sub-processes
if [ "$1" = "backnotify" ]; then backgroundnotify; exit 0; fi;
if [ "$1" = "userlogon" ]; then userlogon; exit 0; fi;

#Network and misc checks
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then exit 0; fi; #Only 1 main instance allowed
if [ $# -eq 0 ]; then "$0" "XS"& exit 0; fi;                       #Run in background
waiting=1;waited=0; while [ $waiting = 1 ]
do ping -c 1 www.google.com && waiting=0;
if [ $waiting = 1 ]; then if [ $waited -ge 60 ]; then exit; fi;    #Wait up to 5 minutes for network
sleep 5; waited=$(($waited+1)); fi; done;
sleep 8; pgrep apacman && exit;

#Start log and background notifications
echo "init">$logfile; for usr in `ls /home|grep -v "Public"`; do if [ -d "/home/$usr/.cache" ]; then
mkdir -p "/home/$usr/.cache/XS"; echo "tmp" > /home/$usr/.cache/XS/logonnotify; chown -R $usr "/home/$usr/.cache/XS"; fi; done;
"$0" "backnotify"& bkntfypid=$!;

#Check for, download, and install updates; Remove obsolete packages
($pacclean; pacman-mirrors -g -c United_States;)  2>&1 |tee -a $logfile;
sudo pacman -S --needed --noconfirm archlinux-keyring manjaro-keyring manjaro-system 2>&1 |tee -a $logfile;
(pacman-key --refresh-keys; pacman-optimize; sync;)  2>&1 |tee -a $logfile;
apacman -Syyu --needed --noconfirm  2>&1 |tee -a $logfile
(pacman -Rnsc $(pacman -Qtdq) --noconfirm; $pacclean;)  2>&1 |tee -a $logfile

#Finish
kill $bkntfypid;
msg="System update finished"; grep "Total Installed Size:" $logfile && msg="$msg \nPackages successfully updated"
grep "new signatures:" $logfile && msg="$msg \nSecurity signatures updated"
grep "Total Removed Size:" $logfile && msg="$msg \nObsolete packages removed"
if [ ! "$msg" = "System update finished" ]; then msg="$msg \nDetails: $logfile"; fi;
if [ "$msg" = "System update finished" ]; then msg="System up-to-date, no changes made"; fi;
killmsg; sendall "$msg"; sleep 10; killmsg;
grep -v "warning" $logfile |grep -E "linux[0-9]{2,3}" && (killmsg; sendall "Kernel and/or drivers were updated. A restart is highly advised";)
echo "XS-done">>$logfile; exit 0;
