#!/bin/bash
#Auto Update For Manjaro by Lectrode
vsn="v3.9.12-hf2"; vsndsp="$vsn 2024-08-09"
#-Downloads and Installs new updates
#-Depends: coreutils, grep, pacman, pacman-mirrors, iputils
#-Optional Depends: flatpak, notify-desktop, pikaur, rebuild-detector, wget

#   Copyright 2016-2024 Steven Hoff (aka "lectrode")

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


#-----------------------
#----Define Functions---
#-----------------------

slp(){ sleep "$1" || read -rt "$1" < /dev/tty; } 2>/dev/null
to_int(){ [[ "$1" =~ ^[\-]?[0-9]+$ ]] && echo "$1" || echo 0; }
trbl_s(){ cat < /dev/stdin|sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' |tr -cd '\11\12\15\40-\176'; }
trbl_t(){ cat < /dev/stdin|trbl_s|tee -a "$log_f"; }
trbl_o(){ echo -e "$@"; (echo -e "$@"|trbl_s)>> "$log_f"; }
trbl(){ trbl_o "\n${co_g}#XS# $(date) -${co_n} $*${co_n}\n"; }
trblm(){ trbl_o "${co_g2}XS-\033[0m$*${co_n}"; }

trblqin(){ ((logqueue_i++)); logqueue[$logqueue_i]="\n${co_g}#XS# $(date) -${co_n} $*${co_n}\n"; }
trblqout(){
    i=0; while [ $i -lt ${#logqueue[@]} ]; do
        trbl_o "${logqueue[$i]}"; ((i++))
    done; unset logqueue logqueue_i i
}

test_online(){ ping -c 1 "${conf_a[main_testsite_str]}" >/dev/null 2>&1 && return 0; return 1; }

chk_pkginst(){ $pcmbin -Q "$1" >/dev/null 2>&1 || return 1; }
chk_pkginstx(){ [[ "$($pcmbin -Qq "$1" 2>/dev/null | grep -m1 -x "$1")" == "$1" ]] || return 1; }
get_pkgqi() { $pcmbin -Qi "$1" 2>/dev/null|grep -E "$2[ ]+:"|grep -oP "(?<=\s:\s).*$"; }
get_pkgqix() { get_pkgqi "$1" "$2"|tr ' ' '\n'|grep -P "[0-9A-z]"; }
chk_pkgexplicit(){ get_pkgqi "$1" "Install Reason"|grep "Explicitly" >/dev/null && return 0; return 1; }
get_pkgvsn(){ $pcmbin -Q "$1"|grep "$1 " -m1|cut -d' ' -f2; }
chk_pkgvsndiff(){ local cpvd_t1; cpvd_t1="$(get_pkgvsn "$1")"; vercmp "${cpvd_t1:-0}" "$2"; }
chk_sha256(){ [[ "$(sha256sum "$1"|cut -d ' ' -f 1 |tr -cd '[:alnum:]')" = "$2" ]] && return 0; return 1; }

dl_outstd(){
#$1=url
if wget --help >/dev/null 2>&1; then
    wget -qO- "$1"|grep -P "[0-9A-z]" && return 0; fi
curl -sL "$1" && return 0; return 1
}
dl_outfile()(
#$1=url $2=output dir
if [[ ! -d "$2" ]]; then mkdir "$2" || return 1; fi
pushd "$2">/dev/null 2>&1 || return 1
if wget --help >/dev/null 2>&1; then
    wget -q "$1" -O "$(basename "$1")" && return 0; fi
curl -sZL "$1" -o "$(basename "$1")" && return  0; return 1
)
dl_clean(){ [[ -d "/tmp/xs-autmp-$1" ]] && rm -rf "/tmp/xs-autmp-$1"; }
dl_verify(){
#$1=id; $2=remote hash; $3=remote file
local dl_hash; dl_hash="$(dl_outstd "$2" |tr -cd '[:alnum:]')"
if [ "${#dl_hash}" = "64" ]; then
    (dl_outfile "$3" "/tmp/xs-autmp-$1/") 2>&1|trbl_t
    chk_sha256 "/tmp/xs-autmp-$1/$(basename "$3")" "$dl_hash" && return 0
fi; dl_clean "$1"; return 1
}

chk_remoterepo(){ pacman -Slq 2>/dev/null|grep -E "^$1$" >/dev/null && return 0; return 1; }
chk_remoteaur(){ dl_outstd "${url_aur}?v=5&type=info&arg[]=$1" |grep -F '"resultcount":0' >/dev/null || return 0; return 1; }
chk_remoteany(){ chk_remoterepo "$1" && return 0; chk_remoteaur "$1" && return 0; return 1; }

get_pkgbuilddate(){
local gpbd_date; gpbd_date="$(get_pkgqi "$1" "Build Date")"
[[ "$gpbd_date" = "" ]] && return 1
date -d "$gpbd_date" +'%Y%m%d' 2>/dev/null || return 1
return 0
}

chk_builtbefore(){
chk_pkginstx "$1" || return 1
local cbdo; cbdo="$(get_pkgbuilddate "$1")"
[[ ! "$cbdo" = "0" ]] && [[ "$cbdo" -le "$2" ]] && return 0; return 1
}

get_pacmancfg(){
#$1=prop
if pacman-conf --help >/dev/null 2>&1; then
    pacman-conf "$1" 2>/dev/null|sed 's:/*$::'
    [[ "${PIPESTATUS[0]}" = "0" ]] && return
fi
if [[ -f /etc/pacman.conf ]]; then
    local gpcc; gpcc="$(grep -E "^[^#]?$1" /etc/pacman.conf |sed -r 's/ += +/=/g'|cut -d'=' -f2)"
    if [[ ! "$gpcc" = "" ]]; then echo "$gpcc"|sed -r 's_/+_/_g'|sed 's:/*$::'; return; fi; fi
if [[ "$1" = "DBPath" ]]; then echo "/var/lib/pacman"; fi
if [[ "$1" = "CacheDir" ]]; then echo "/var/cache/pacman/pkg"; fi
}

get_pkgfiles(){
#$1=pkg name
{ for f in "$(get_pacmancfg CacheDir)" "/var/cache/pikaur/pkg" "/var/cache/apacman/pkg"; do compgen -G "$f/$1-*.pkg.*"; done; }|\
    grep -P "/$1-[0-9.+:A-z]+-[0-9.]+-[0-9A-z_]+\.pkg\.[0-9A-z]+\.[0-9A-z]+$"|sort -rV
}

inst_misspkg(){
trbl "$2. Installing missing dependency: $1"
if chk_remoterepo "$1"; then $pcmbin -S --noconfirm "$1"|trbl_t; return; fi
for h in pikaur apacman; do if [ "${hlpr_a[$h]}" = "1" ]; then $h -S --needed --noconfirm "$1"; break; fi; done
}

pcln_fol(){
#$1=num, $2=fol
[[ -d "$2" ]] || return
# shellcheck disable=SC2115
if [[ "$1" = "0" ]]; then rm -rf "$2"/*; return; fi
if ! paccache --help >/dev/null 2>&1 && chk_remoterepo "pacman-contrib"; then
    inst_misspkg "pacman-contrib" "Cleanup enabled and configured to use paccache"; fi
if paccache --help >/dev/null 2>&1; then paccache -rfqk"$1" -c "$2"
else trbl "$co_y cannot clean $2, paccache not found/functioning"; fi
}
pacclean(){
[[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] || return

[[ "$((conf_a[cln_aurpkg_num]+conf_a[cln_aurbuild_bool]+conf_a[cln_paccache_num]))" -gt "-2" ]] && trbl "Performing cleanup operations..."

if [[ "${conf_a[cln_aurpkg_num]}" -gt "-1" ]]; then
    trblm "Cleaning AUR package cache..."
    pcln_fol "${conf_a[cln_aurpkg_num]}" "/var/cache/apacman/pkg"
    pcln_fol "${conf_a[cln_aurpkg_num]}" "/var/cache/pikaur/pkg"
fi

if [[ "${conf_a[cln_aurbuild_bool]}" = "$ctrue" ]]; then
    trblm "Cleaning AUR build cache..."
    pcln_fol 0 "/var/cache/pikaur/aur_repos"
    pcln_fol 0 "/var/cache/pikaur/build"
fi

if [[ "${conf_a[cln_paccache_num]}" -gt "-1" ]]; then
    trblm "Cleaning pacman cache..."
    pcln_fol "${conf_a[cln_paccache_num]}" "$(get_pacmancfg CacheDir)"
fi
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

manualExplicit(){
chk_pkginstx "$1" || return 0
chk_pkgexplicit "$1" && return 0
$pcmbin -D --asexplicit "$1"|trbl_t
chk_pkgexplicit "$1" && return 0 || return 1
}

manualDepend(){
chk_pkginstx "$1" || return 0
chk_pkgexplicit "$1" || return 0
$pcmbin -D --asdeps "$1"|trbl_t
chk_pkgexplicit "$1" && return 1 || return 0
}

manualRemoval(){
#$1=(pkgs)|$2=vsn (or older) to remove|[$3=new pkgs][$4="now"]
local mr_pkgo mr_expl; IFS=" " read -ra mr_pkgo <<< "$1"
if chk_pkginstx "${mr_pkgo[0]}" && { [[ "$2" = "" ]] || [[ "$(chk_pkgvsndiff "${mr_pkgo[0]}" "$2")" -le 0 ]]; }; then
    trbl "attempting manual package removal/replacement of $1..."
    if [[ ! "$3" = "" ]]; then
        mr_expl=$false; chk_pkgexplicit "${mr_pkgo[0]}" && mr_expl=$true
        # shellcheck disable=SC2086
        $pcmbin -Sw --noconfirm $3 $sf_ignore 2>&1|trbl_t
        if [[ ! "${PIPESTATUS[0]}" = "0" ]] && [[ "$4" = "now" ]]; then trbl "$co_y failed to download $3"; return 1; fi
    fi
    for p in "${mr_pkgo[@]}"; do chk_pkginstx "$p" && $pcmbin -Rdd --noconfirm "$p" 2>&1|trbl_t; done
    if [[ "$4" = "now" ]]; then
        # shellcheck disable=SC2086
        [[ "$3" = "" ]] || $pcmbin -S --noconfirm $3 $sf_ignore 2>&1|trbl_t
        if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then trbl "$co_r failed to replace $1 with $3"; fi
    else
        if [[ "$mr_expl" = "$true" ]]; then installLater+=" $3"
        else installLaterDep+=" $3"; fi
    fi
fi
}

disableSigsUpdate(){
[[ -f "/etc/pacman.conf.xsautoupdate.orig" ]] && mv -f "/etc/pacman.conf.xsautoupdate.orig" "/etc/pacman.conf"  2>&1|trbl_t
if cp -f "/etc/pacman.conf" "/etc/pacman.conf.xsautoupdate.orig" >/dev/null 2>&1; then
    sed -i 's/SigLevel.*/SigLevel = Never/' /etc/pacman.conf
    # shellcheck disable=SC2086
    $pcmbin -S --noconfirm $1 $sf_ignore 2>&1|trbl_t
    mv -f "/etc/pacman.conf.xsautoupdate.orig" "/etc/pacman.conf"  2>&1|trbl_t
fi
$pcmbin -Quq|grep -E "^$1$" >/dev/null 2>&1 && return 1
return 0
}

pkgdl_vsn(){
#$1=pkg,$2=version
#check if already in cache
get_pkgfiles "$1"|grep "$1-$2"|head -n1 2>/dev/null
[[ "${PIPESTATUS[1]}" = "0" ]] && return 0
#download from arch archive
local md_pkg; md_pkg="$(dl_outstd "${url_ala}/${1:0:1}/${1}"|grep -F "$1-$2-"|grep -oP "[^<>\"]+-[0-9A-z_]+\.pkg\.[0-9A-z]+\.[0-9A-z]+"|sort -u|head -n1)"
[[ "$md_pkg" = "" ]] || dl_outfile "${url_ala}/${1:0:1}/${1}/$md_pkg" "$(get_pacmancfg CacheDir)"
if [[ -f "$(get_pacmancfg CacheDir)/$md_pkg" ]]; then echo "$(get_pacmancfg CacheDir)/$md_pkg"; return 0; fi
return 1
}

manualReinst(){
#$1=pkg|path
local mdl_s mdl_d; mdl_s="S"
if echo "$1"|grep ".pkg.">/dev/null 2>&1; then mdl_s="U"; mdl_d="dd"; fi
while : ; do
    if [[ "$mdl_s" = "S" ]]; then test_online || return 1; fi
    # shellcheck disable=SC2086
    $pcmbin -${mdl_s}${mdl_d} --noconfirm --overwrite=* $1 $pacignore 2>&1|trbl_t|tee /dev/tty|grep "could not satisfy dependencies" >/dev/null
    if [[ ! "${PIPESTATUS[0]}" -eq 0 ]] && [[ "${PIPESTATUS[3]}" -eq 0 ]]; then
        if [[ ! "$mdl_d" = "dd" ]]; then mdl_d="${mdl_d}d"; trbl "$co_y skipping dependency detection ($mdl_d)"; continue
        else return 1; fi
fi; return 0; done
}

checkRepairDb(){
#$1=(cache|repo)
trbl "Checking for database errors [$1]..."
local rpdb_path rpdb_pkgn rpdb_pkgv rpdb_pkgf

if [[ "${conf_a[repair_1enable_bool]}" = "$cfalse" ]] || [[ "${conf_a[repair_db01_bool]}" = "$cfalse" ]]; then
    [[ "$1" = "repo" ]] && return 0
    if [[ "$($pcmbin -Dk 2>&1|grep -Eic "error:.+(description file|file list) is missing$")" -gt "0" ]]; then
        trbl "$co_y system has missing files in package database. Automatic fix is disabled in config; reporting only."
        $pcmbin -Dk 2>&1|trbl_t; return 1
fi; return 0; fi

for p in $(pacman -Dk 2>&1 | grep -Ei "error: '.+': (description file|file list) is missing"|sed 's/: /#/g'|cut -d'#' -f2|grep -oP "[0-9A-z:@._+-]+"|sort -u); do
    rpdb_path="$(get_pacmancfg DBPath)/local/$p"
    rpdb_pkgn="$(echo "$p"|grep -oP '.+?(?=-[0-9A-z:._+]+-[0-9.]+$)')"
    rpdb_pkgv="$(echo "$p"|grep -oP '[0-9A-z:._+]+-[0-9.]+$')"
    trbl "$co_y Database files for $rpdb_pkgn are corrupt or missing"
    trblm "Getting installer for $rpdb_pkgn [$rpdb_pkgv]"
    rpdb_pkgf="$(pkgdl_vsn "$rpdb_pkgn" "$rpdb_pkgv")" #use cache copy, or dl from archive
    if [[ "$rpdb_pkgf" = "" ]] || [[ ! -f "$rpdb_pkgf" ]]; then
        if [[ "$1" = "cache" ]]; then trbl "$co_y installer not found for $rpdb_pkgn , will attempt to download later"; continue; fi; fi
    #create missing files
    mkdir -p "$rpdb_path"
    for c in files desc; do
        [[ -f "${rpdb_path}/$c" ]] && continue; trblm "Creating missing file: ${rpdb_path}/$c"
        touch "${rpdb_path}/$c" || trbl "$co_y could not create $c"
    done
    #reinstall pkg
    if [[ "$rpdb_pkgf" = "" ]] || [[ ! -f "$rpdb_pkgf" ]]; then
        trblm "Reinstalling $rpdb_pkgn"; manualReinst "$rpdb_pkgn" "y"
    else trblm "Reinstalling $(basename "$rpdb_pkgf")"; manualReinst "$rpdb_pkgf" "y"; fi
    #undo desc/files changes if above fails
    for c in files desc; do [[ "$(stat -c%s "${rpdb_path}/$c" 2>/dev/null)" = "0" ]] && rm "${rpdb_path}/$c"; done
done
}


#Persistant Data Functions

perst_isneeded(){
#$1 = xxx_xxx_freq,$2 = perst_a[var]
if [[ "$1" -eq "-1" ]]; then return 1; fi
local curdate; curdate=$(date +'%Y%m%d')
scheddate=$(date -d "$2 + $1 days" +'%Y%m%d')
if [[ "$scheddate" -le "$curdate" ]]; then return 0
elif [[ "$2" -gt "$curdate" ]]; then return 0
else return 1; fi
}

perst_update(){
#$1=var
perst_a[$1]=$(date +'%Y%m%d'); echo "$1=${perst_a[$1]}" >> "$perst_f"
echo "$1" | grep -F "zrbld:" >/dev/null && \
    rbld_a["$(echo "$1" | cut -d ':' -f 2)"]=$(date +'%Y%m%d')
}

perst_export(){
touch "$perst_f"
echo "#persistent cache data for xs-update-manjaro" > "$perst_f"
for i in $(printf "%s\n" "${!perst_a[@]}"|sort); do
    echo "$i=${perst_a[$i]}" >> "$perst_f"
done
}

perst_reset(){
if echo "$1" | grep -F "zrbld:" >/dev/null; then
    unset "rbld_a[$(echo "$1" | cut -d ':' -f 2)]" "perst_a[$1]"
    perst_export #cannot use sed, as [] is treated as regex
else perst_a[$1]="20010101"; echo "$1=20010101" >> "$perst_f"; fi
}

aurrebuildlist(){
local arlist arignore arlist_grep
readarray -t arlist < <(checkrebuild 2>/dev/null|grep -oP '^foreign\s+\K(?!.*-bin$)([\w\.@\+\-]*)$')

#remove stale rebuild cache entries
arlist_grep="$(echo -n "${arlist[@]}"|tr ' ' '|')"
for pkg in "${!rbld_a[@]}"; do
    if [[ "${#arlist[@]}" = "0" ]] || ! echo "$pkg"|grep -E "^($arlist_grep)$" >/dev/null; then
        perst_reset "zrbld:$pkg"; fi
done

#remove ignored entries
arignore="$(echo -n "$(echo "${conf_a[main_ignorepkgs_str]}"; get_pacmancfg IgnorePkg; echo "${!rbld_a[@]}")"|tr '\n' ' '|sed 's/ /|/g')"
[[ "$arignore" = "" ]] || readarray -t arlist < <(echo "${arlist[@]}"|tr ' ' '\n'|grep -Evi "^($arignore)$")

#exclude orphan packages from list
for pkg in "${arlist[@]}"; do
    if ! chk_remoteaur "$pkg"; then
        [[ "${perst_a[$pkg]}" = "" ]] || perst_reset "zrbld:$pkg"
    else echo "$pkg"; fi
done
}


#Notification Functions

iconnormal(){ icon=emblem-default; [[ -f "/usr/share/pixmaps/ElectrodeXS.png" ]] && icon=ElectrodeXS; }
iconwarn(){ icon=dialog-warning; }
iconcritical(){ icon=system-shutdown; }
iconerror(){ icon=dialog-error; }

sendmsg(){
#$1=user; $2=msg; [$3=timeout]
if [[ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]] && [[ "$((noti_desk+noti_send+noti_gdbus))" -le 2 ]]; then
    noti_id["$1"]="$(to_int "${noti_id["$1"]}")"
    local tmp_t0 tmp_t1; tmp_t0="$(to_int "$3")"
    if [ "$tmp_t0" = "0" ]; then
        tmp_t1="-u critical"
    else ((tmp_t0*=1000)); tmp_t1="-t $tmp_t0"; fi
    if [ "$noti_desk" = "$true" ]; then
        if [[ "$2" = "dismiss" ]]; then
            noti_id["$1"]="$(su "$1" -c "notify-desktop -u normal -r ${noti_id["$1"]} \" \" -t 1")"
        else
            tmp_m1="${2//\\n/$'\n'}"
            noti_id["$1"]="$(su "$1" -c "notify-desktop -i $icon $tmp_t1 -r ${noti_id["$1"]} xs-auto-update \"$notifyvsn$tmp_m1\" 2>/dev/null || echo error")"
        fi
    fi
    if [ "$noti_send" = "$true" ]; then
        if [[ ! "$2" = "dismiss" ]]; then
            noti_id["$1"]="$(su "$1" -c "notify-send -i $icon $tmp_t1 xs-auto-update \"$notifyvsn$2\" 2>/dev/null || echo error")"
        fi
    fi
    if [ "$noti_gdbus" = "$true" ]; then
        if [[ "$2" = "dismiss" ]]; then
            noti_id["$1"]="$(su "$1" -c "gdbus call --session --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification ${noti_id["$1"]}")"
        else
            noti_id["$1"]="$(su "$1" -c "gdbus call --session --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify \
                xs-auto-update ${noti_id["$1"]} $icon xs-auto-update \"$notifyvsn$2\" [] {} $tmp_t0 2>/dev/null || echo error"|cut -d' ' -f2|cut -d',' -f1)"
        fi
    fi
    if [[ "${noti_id["$1"]}" = "error" ]]; then noti_id["$1"]=0; return 1; fi
fi; return 0
}

getsessions(){
local i usr disp usrhome sssn; i=0
unset s_usr s_disp s_home; while read -ra sssn; do
    loginctl show-session -p Active "${sssn[0]}" 2>/dev/null |grep -F "yes" >/dev/null 2>&1 || continue
    usr="$(loginctl show-session -p Name "${sssn[0]}"|cut -d'=' -f2)"
    disp="$(loginctl show-session -p Display "${sssn[0]}"|cut -d'=' -f2)"
    [[ "$disp" = "" ]] && disp=":0" #workaround for gnome, which returns nothing
    usrhome="$(getent passwd "$usr"|cut -d: -f6)"
    [[  ${usr-x} && ${disp-x} && ${usrhome-x} ]] || continue
    s_usr[i]=$usr; s_disp[i]=$disp; s_home[i]=$usrhome; ((i++))
done <<< "$(loginctl list-sessions --no-legend 2>/dev/null)"; slp 1
}

sendall(){
[[ "${conf_a[notify_1enable_bool]}" = "$ctrue" ]] || return 0
getsessions; local sa_err i; sa_err=0; i=0; while [ $i -lt ${#s_usr[@]} ]; do
    DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${s_usr[$i]}")/bus" \
        sendmsg "${s_usr[$i]}" "$1" "$2" || sa_err=1
((i++)); done; return $sa_err
}

backgroundnotify(){
iconwarn; while : ; do
    if [[ -f "${perst_d}/auto-update_termnotify.dat" ]]; then 
        sendall "dismiss"; rm -f "${perst_d}/auto-update_termnotify.dat"; slp 2; exit 0; fi
    slp 2; getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
        if [ -f "${s_home[$i]}/.cache/xs/logonnotify" ]; then
            DISPLAY=${s_disp[$i]} XAUTHORITY="${s_home[$i]}/.Xauthority" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${s_usr[$i]}")/bus" \
                sendmsg "${s_usr[$i]}" "System is updating (please do not turn off the $device)\nDetails: $log_f" \
                && rm -f "${s_home[$i]}/.cache/xs/logonnotify"
        fi; ((i++))
    done; [[ ${#s_usr[@]} -eq 0 ]] && slp 3
done; }

userlogon_crit(){
iconcritical; notify-send -i $icon xs-auto-update -u critical \
"Kernel and/or drivers were updated. Please restart your $device to finish"
}
userlogon_chkkrnl(){
for k in $(file /boot/vmlinuz*|grep -oE "version [^ ]+"|sed 's/version //g'); do
    [[ "$k" = "$(uname -r)" ]] && return 0; done
pacman --help >/dev/null 2>&1 || return 1
local kerns; kerns="$( (pacman -Qq;pacman -Slq)|grep -oE "^linux[^ ]+-headers$"|sed 's/-headers//g'|tr '\n' '|'|sed 's:|*$::' )"
for k in $(pacman -Qq|grep "^linux"|grep -E "^($kerns)$"); do
    [[ "$(get_pkgvsn "$k"|grep -oE "[0-9]+.[0-9]+.[0-9]+")" = "$(uname -r|grep -oE "[0-9]+.[0-9]+.[0-9]+")" ]] && return 0
done; return 1
}
userlogon(){
slp 5; [[ -d "$HOME/.cache/xs" ]] || mkdir -p "$HOME/.cache/xs"
if pidof -o %PPID -x "$(basename "$0")">/dev/null; then touch "$HOME/.cache/xs/logonnotify"
else
    if ! userlogon_chkkrnl; then userlogon_crit
    elif lsof -h >/dev/null 2>&1; then
        lsof +c 0|grep 'DEL.*lib' >/dev/null && userlogon_crit; fi
fi
}

exit_passive(){
trbl "XS-done"; sync; n=0
while jobs|grep Running >/dev/null && [[ $n -le 15 ]] ; do ((n++)); slp 2; done
systemctl stop xs-autoupdate.service >/dev/null 2>&1; exit 0
}

exit_active(){
#$1 = reason
secremain=${conf_a[reboot_delay_num]}
systemd-inhibit --what="sleep:idle:handle-suspend-key:handle-hibernate-key:handle-lid-switch" sleep $((secremain+60)) &
actn_cmd="${conf_a[reboot_action_str]}"
ignoreusers="${conf_a[reboot_ignoreusers_str]// /\\|}"
iconcritical; trbl "Active Exit: $actn_cmd";trbl "XS-done"; sync &
while [ "$secremain" -gt 0 ]; do
    usersexist=$false; loginctl list-sessions --no-legend |grep -v "$ignoreusers" |grep "seat\|pts" >/dev/null && usersexist=$true

    if [ "${conf_a[reboot_delayiflogin_bool]}" = "$ctrue" ]; then
        if [ "$usersexist" = "$false" ]; then trblm "No logged-in users detected; System will $actn_cmd now"; secremain=0; slp 1; continue; fi; fi

    if [[ "$usersexist" = "$true" ]]; then sendall "$1\nYour $device will $actn_cmd in \n$secremain seconds..."; fi
    slp "${conf_a[reboot_notifyrep_num]}"
    ((secremain-=conf_a[reboot_notifyrep_num]))
done
sync; $actn_cmd || systemctl --force "$actn_cmd" || systemctl --force --force "$actn_cmd"
}

conf_validstr(){ echo "$val" |grep -E "^($1)\$" >/dev/null || return 1; return 0; }

conf_valid(){
#parse and validate lines from config and persistant data files
local parse; parse="$(echo "$line" | cut -d ';' -f 1 | cut -d '#' -f 1)"
echo "$parse" | grep -F '=' &>/dev/null || return 1

varname="$(echo "$parse" | cut -d '=' -f 1)"
val="$(echo "$line" | cut -d '=' -f 2-)"

if ! echo "$varname"|grep -E "($validconf)" >/dev/null; then
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
[[ -d "$(dirname "$xs_autoupdate_conf")" ]] || mkdir "$(dirname "$xs_autoupdate_conf")"
cat << 'EOF' > "$xs_autoupdate_conf"
#Config for XS-AutoUpdate
#bool: 1=true; 0=false

# AUR Settings #
#aur_1helper_str:          Valid options are auto,none,all,pikaur,apacman
#aur_aftercritical_bool:   Enable/Disable AUR updates immediately after critical system updates
#aur_update_freq:          Update AUR packages every X days
#aur_devel_freq:           Update -git and -svn AUR packages every X days (-1 to disable, best if a multiple of aur_update_freq, pikaur only)

# Cleanup Settings #
#cln_1enable_bool:         Enable/Disable ALL package cleanup (overrides following cleanup settings)
#cln_aurpkg_num:           Number of AUR packages to keep (-1 to keep all)(any values greater than 0 require paccache)
#cln_aurbuild_bool:        Enable/Disable AUR build cleanup
#cln_flatpakorphan_bool:   Enable/Disable uninstall of uneeded flatpak packages
#cln_orphan_bool:          Enable/Disable uninstall of uneeded repo packages
#cln_paccache_num:         Number of repo packages to keep (-1 to keep all)(any values greater than 0 require paccache)

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
#main_inhibit_bool:        Enable/Disable preventing normal user shutdown,reboot,suspend while updating
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
for i in $(printf "%s\n" "${!conf_a[@]}"|sort); do
    echo "$i=${conf_a[$i]}" >> "$xs_autoupdate_conf"
done
}



#-----------------------
#-------Initialize------
#-----------------------

# misc vars

set $debgn; pcmbin="pacman"; pacmirArgs="--geoip"
true=0; false=1; ctrue=1; cfalse=0
co_n='\033[0m';co_g='\033[1;32m';co_g2='\033[0;32m';co_r='\033[1;31m[Error]';co_y='\033[1;33m[Warning]'
url_repo="https://raw.githubusercontent.com/lectrode/xs-update-manjaro"
url_aur="https://aur.archlinux.org/rpc/"
url_ala="https://archive.archlinux.org/packages"
typeset -A err; typeset -A logqueue; logqueue_i=-1
[[ "$xs_autoupdate_conf" = "" ]] && xs_autoupdate_conf='/etc/xs/auto-update.conf'
device="device"; [[ "$(uname -m)" = "x86_64" ]] && device="computer"
sf_ignore="$(get_pacmancfg "SyncFirst"|tr -s ' ')"
if [[ ! "$sf_ignore" = "" ]]; then sf_ignore="--ignore ${sf_ignore// / --ignore }"; fi

#config: defaults

typeset -A flag_a
typeset -A conf_a; conf_a=(
    [aur_1helper_str]="auto"
    [aur_aftercritical_bool]=$cfalse
    [aur_update_freq]=3
    [aur_devel_freq]=6
    [cln_1enable_bool]=$ctrue
    [cln_aurpkg_num]=1
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
    [main_inhibit_bool]=$ctrue
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
    [repair_db02_bool]=$ctrue
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
    [cln_aurpkg_bool]=""
)
validconf="$(IFS='|'; echo "${!conf_a[*]}")"
conf_int0="notify_lastmsg_num reboot_delay_num reboot_notifyrep_num"
conf_intn1="cln_aurpkg_num cln_paccache_num reboot_1enable_num"
conf_legacy="bool_detectErrors bool_Downgrades bool_notifyMe bool_updateFlatpak bool_updateKeys str_cleanLevel \
    str_ignorePackages str_log_d str_mirrorCountry str_testSite aur_devel_bool flatpak_1enable_bool \
    reboot_1enable_bool repair_pythonrebuild_bool cln_aurpkg_bool"

#config: load from file

if [[ -f "$xs_autoupdate_conf" ]]; then
    while read -r line; do

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
[[ "${conf_a[cln_aurpkg_bool]}" = "0" ]] && conf_a[cln_aurpkg_num]="-1"

for i in $(printf "%s\n" "$conf_legacy"); do unset "conf_a[$i]"; done


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
        elif chk_pkginst "plasma-desktop"; then
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
    echo "Critical error: could not create log directory"; slp 10; exit; fi
log_d="${conf_a[main_logdir_str]}"; log_f="${log_d}/auto-update.log"
if [[ ! -f "$log_f" ]]; then echo "init">"$log_f"; fi


#perst
if [ "${conf_a[main_perstdir_str]}" = "" ]; then perst_d="$log_d"
else perst_d="${conf_a[main_perstdir_str]}"; fi
mkdir -p "$perst_d"; if [ ! -d "$perst_d" ]; then
    conf_a[main_perstdir_str]="${conf_a[main_logdir_str]}"; perst_d="${conf_a[main_logdir_str]}"; fi
perst_f="${perst_d}/auto-update_persist.dat"

typeset -A rbld_a
typeset -A perst_a; perst_a=(
    [aur_up_date]="20000101"
    [aurdev_up_date]="20000101"
    [flatpak_up_date]="20000101"
    [keys_up_date]="20000101"
    [mirrors_up_date]="20000101"
)
validconf="$(IFS='|'; echo "${!perst_a[*]}")"
if [[ -f "$perst_f" ]]; then
    while read -r line; do

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
(echo)>"$log_f";trbl "${co_g}xs-auto-update $vsndsp initialized..."
trblm "Config file: $xs_autoupdate_conf"; trblqout


#-----------------------
#------Main Script------
#-----------------------


#Wait up to 5 minutes for network
trbl "Waiting up to 5 minutes for network..."
i=0; while : ; do
    test_online && break
    if [[ $i -ge 60 ]]; then trbl "No network; quitting..."; exit; fi
    slp 5; ((i++))
done; unset i

slp 8 # In case connection just established

#Check for updates for self
if [[ "${conf_a[self_1enable_bool]}" = "$ctrue" ]]; then
    trbl "Checking for self-updates [branch: ${conf_a[self_branch_str]}]..."
    vsn_new="$(dl_outstd "$url_repo/master/vsn_${conf_a[self_branch_str]}" | tr -cd '[:alnum:]+-.')"
    vsn_newc="$(echo "$vsn_new" | cut -d '+' -f 1)"
    if [[ ! "$vsn_newc" = "$(echo -e "$vsn_newc\n$vsn"|sort -V|head -n1)" ]]; then
        if dl_verify "selfupdate" "$url_repo/${vsn_new}/hash_auto-update-sh" "$url_repo/${vsn_new}/auto-update.sh"; then
            trblm "==================================="
            trblm "Updating script to $vsn_new..."
            trblm "==================================="
            mv -f '/tmp/xs-autmp-selfupdate/auto-update.sh' "$0"
            chmod +x "$0"; "$0" "XS"& exit 0
        fi
    fi; unset vsn_new vsn_newc; dl_clean "selfupdate"
fi

#wait up to 5 minutes for running instances of pacman/pikaur/apacman
trbl "Waiting for pacman/pikaur/apacman..."
i=0; while : ; do
    if pgrep -x "(pacman(-static)*|pikaur|apacman)" >/dev/null; then
        if [[ $i -ge 60 ]]; then trbl "Other software is updating; quitting..."; exit; fi
        slp 5; ((i++))
    else break; fi
done;  unset i

#remove .lck file (updaters not running at this point)
if [[ -f "$(get_pacmancfg DBPath)/db.lck" ]]; then rm -f "$(get_pacmancfg DBPath)/db.lck"; fi
if [[ -f "/tmp/pikaur_build_deps.lock" ]]; then rm -f "/tmp/pikaur_build_deps.lock"; fi

#init background notifications
trbl "init notifier..."
rm -f "${perst_d}/auto-update_termnotify.dat" >/dev/null 2>&1
getsessions; i=0; while [ $i -lt ${#s_usr[@]} ]; do
if [ -d "${s_home[$i]}/.cache" ]; then
    mkdir -p "${s_home[$i]}/.cache/xs"; echo "tmp" > "${s_home[$i]}/.cache/xs/logonnotify"
chown -R "${s_usr[$i]}" "${s_home[$i]}/.cache/xs"; fi; ((i++)); done; unset i
if [[ "${conf_a[main_inhibit_bool]}" = "$cfalse" ]]; then "$0" "backnotify"&
else systemd-inhibit --what="shutdown:sleep:idle:handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch" "$0" "backnotify"& fi

#check/fix database errors (before any other changes if possible)
checkRepairDb "cache"

#Check for, download, and install main updates
pacclean

if perst_isneeded "${conf_a[update_mirrors_freq]}" "${perst_a[mirrors_up_date]}"; then
    if type pacman-mirrors >/dev/null 2>&1; then
        trbl "Updating Mirrors... [branch: $(pacman-mirrors -G 2>/dev/null)]"
        # shellcheck disable=SC2086
        (pacman-mirrors $pacmirArgs || pacman-mirrors -g) 2>&1|trbl_t
        err[mirrors]=${PIPESTATUS[0]}; if [[ ${err[mirrors]} -eq 0 ]]; then
            perst_update "mirrors_up_date"; else trbl "$co_y pacman-mirrors exited with code ${err[mirrors]}"; fi
    else trbl "pacman-mirrors not found - skipping"; fi
fi

if perst_isneeded "${conf_a[update_keys_freq]}" "${perst_a[keys_up_date]}"; then
while : ; do
    if chk_pkginstx "archlinux-keyring" && chk_builtbefore "archlinux-keyring" "$(date -d"180 days ago" +'%Y%m%d')"; then
        trbl "$co_y installed keys are more than 6 months old; skipping manual key refresh due to likely failure"; break; fi
    trbl "Refreshing keys..."; pacman-key --refresh-keys  2>&1|trbl_t |tee /dev/tty |grep "Total number processed:" >/dev/null
    err_keys=("${PIPESTATUS[@]}"); if [[ "${err_keys[0]}" -eq 0 ]] || [[ "${err_keys[3]}" -eq 0 ]]; then
        perst_update "keys_up_date"; err[keys]=0; else err[keys]=${err_keys[0]}; trbl "$co_y pacman-key exited with code ${err[keys]}"; fi
unset err_keys; break; done; fi

#While loop for updating main and AUR packages
#Any critical errors will disable further changes
while : ; do

if ! chk_freespace_all; then err[repo]=1; err_crit="repo"; break; fi

#Does not support installs with xproto<=7.0.31-1
if chk_pkginstx "xproto" && [[ "$(chk_pkgvsndiff "xproto" "7.0.31-1")" -le 0 ]]; then
    trbl "$co_r old xproto installed - system too old for script to update"; err[repo]=1; err_crit="repo"; break; fi


trbl "Updating package databases..."
while : ; do test_online || break
pacman -Syy 2>&1|trbl_t|tee /dev/tty|grep "error: GPGME error: No data" >/dev/null
err_repodb=("${PIPESTATUS[@]}"); if [[ ! "${err_repodb[0]}" -eq 0 ]] && [[ "${err_repodb[3]}" -eq 0 ]]; then
    if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_db02_bool]}" = "$ctrue" ]]; then
        if [[ "$uprepodb" = "" ]]; then
            trbl "$co_y Package databases corrupt, fixing..."
            uprepodb=0; [[ -d "$(get_pacmancfg DBPath)/sync" ]] && rm -rf "$(get_pacmancfg DBPath)/sync"/*; continue
        else trbl "$co_y Failed to fix package database corruption. Continuing..."; break; fi
    else trbl "$co_y Package databases corrupt, but fix is disabled. Continuing..."; break; fi
fi; break; done; err[repodb]="${err_repodb[0]}"; unset uprepodb err_repodb

#pacman-static
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then
    #Fix for pacman<5.2 (18.1.1 and earlier)
    if [[ "$(chk_pkgvsndiff "pacman" "5.2.0-1")" -lt 0 ]]; then
        trbl "Old pacman detected, attempting to use pacman-static..."
        pacman -Sw --noconfirm pacman-static 2>&1|trbl_t
        pacman -U --noconfirm "$(get_pkgfiles "pacman-static"|head -n1)" 2>&1|trbl_t && pcmbin="pacman-static"
        if ! chk_pkginst "pacman-static"; then
            if dl_verify "pacmanstatic" "$url_repo/master/external/hash_pacman-static" "$url_repo/master/external/pacman-static"; then
                chmod +x /tmp/xs-autmp-pacmanstatic/pacman-static && pcmbin="/tmp/xs-autmp-pacmanstatic/pacman-static"; fi; fi
        if echo "$pcmbin"|grep "pacman-static" >/dev/null 2>&1 && $pcmbin --help >/dev/null 2>&1; then
            trbl "Using $pcmbin"
        else trbl "$co_r failed to use pacman-static. Cannot update system packages"; err[repo]=1; err_crit="repo"; break; fi
    fi
fi

#Update keyring packages
trbl "Updating system keyring packages..."
for p in $(pacman -Sl|grep "\[installed"|grep "keyring "|grep -Eo "[^ ]*-keyring"|grep -Ev "^([lib]*gnome|python)-keyring$"); do
    # shellcheck disable=SC2086
    $pcmbin -S --needed --noconfirm $p $sf_ignore 2>&1|trbl_t
    if [[ "${PIPESTATUS[0]}" -gt 0 ]]; then
        if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_keyringpkg_bool]}" = "$ctrue" ]]; then
            kr_date="$(get_pkgbuilddate "$p")"; if [[ "$kr_date" = "" ]]; then kr_date="20000101"; fi
            #if build date of the keyring package is 546 or more days ago (~1.5 years), assume too old to update normally
            if perst_isneeded 546 "$kr_date"; then
                trbl "$co_y [$p] is old and failed to update; attempting fix..."
                if ! disableSigsUpdate "$p"; then trbl "$co_r could not update [$p]"; err[sys]=1; break; fi; fi
        else err[sys]=1; fi
    fi
done
if [[ ${err[sys]} -ne 0 ]]; then trbl "$co_r failed to update system keyrings"; err_crit="sys"; break; fi

#check/fix database errors
checkRepairDb "repo"

trbl "Downloading packages from main repos..."
while : ; do test_online || break
# shellcheck disable=SC2086
$pcmbin -Suw$pacdown$pacdep --needed --noconfirm $pacignore 2>&1|trbl_t|tee /dev/tty|grep "could not satisfy dependencies" >/dev/null
err_repodl=("${PIPESTATUS[@]}"); [[ "${conf_a[cln_paccache_num]}" = "0" ]] || pacclean
if [[ ! "${err_repodl[0]}" -eq 0 ]] && [[ "${err_repodl[3]}" -eq 0 ]]; then
    if [[ ! "$pacdep" = "dd" ]]; then pacdep="${pacdep}d"; trbl "$co_y skipping dependency detection ($pacdep)"; continue
    else trbl "$co_y pacman failed to download packages - err code:${err_repodl[0]}"; fi
fi; break; done; unset err_repodl pacdep

if ! chk_freespace_all || ! test_online; then err[repo]=1; err_crit="repo"; break; fi

if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then
    trbl "Checking for required manual package changes..."

    #Details on required changes:
    #https://github.com/lectrode/xs-update-manjaro#supported-automatic-repair-and-manual-changes

    #package install
    if get_pkgqix "pacman" "Provides"|grep -F "pacman-contrib" >/dev/null && chk_remoterepo "pacman-contrib"; then
        trblm "pacman-contrib will be installed with updates"
        manInstDep+=" pacman-contrib"
    fi #install pacman-contrib if previously provided by pacman
    if ! chk_pkginstx "kvantum-qt5" && chk_pkginstx "kvantum" && chk_pkginstx "qt5-base" && [[ "$(chk_pkgvsndiff "kvantum" "1.1.0-1")" -le 0 ]] && chk_remoterepo "kvantum-qt5"; then
        installLaterDep+=" kvantum-qt5"; fi #2024/02/26: split out as opt dep with 1.0.10-3

    #conflict overwrite
    if chk_pkginstx "glibc-locales" && \
        { [[ "$(chk_pkgvsndiff "glibc-locales" "2.38-5")" -le 0 ]] || [[ "$(chk_pkgvsndiff "glibc" "2.38-5")" -le 0 ]] ; }; then
        trblm "contents of /usr/lib/locale will be overwritten with glibc/locales update"
        manOvWrt+=" --overwrite=/usr/lib/locale/*"; fi #2023/10/01: split package (glibc) conflicts with old

    #mark packages as explicitely installed
    if chk_pkginstx "kvantum-manjaro" && [[ "$(chk_pkgvsndiff "kvantum-manjaro" "0.13.5+1+g333aa00-1")" -lt 0 ]]; then
        for t in adapta-black-breath-theme adapta-black-maia-theme adapta-breath-theme adapta-gtk-theme adapta-maia-theme arc-themes-maia \
            arc-themes-breath matcha-gtk-theme; do manualExplicit "$t"; done; fi #removed from depends of kvmantum-manjaro 2022/02/23
    if chk_pkginstx "manjaro-xfce-settings" && [[ "$(chk_pkgvsndiff "manjaro-xfce-settings" "20200109-1")" -lt 0 ]]; then
        for t in vertex-maia-icon-theme breath-wallpaper; do manualExplicit "$t"; done; fi #removed from depends of manjaro-xfce-settings 2020/01/09

    #mark packages as depends
    if chk_pkginstx "phonon-qt4" && [[ "$(chk_pkgvsndiff "phonon-qt4" "4.11.0")" -lt 0 ]]; then
        for t in phonon-qt4-gstreamer phonon-qt4-vlc phonon-qt4-mplayer-git; do manualDepend "$t"; done; fi #these should be depends of phonon-qt4, moved to AUR 2019/05

    #package removal
    manualRemoval "vlc-plugin-fluidsynth-bin" "1:3.0.20.1-1"; manualRemoval "vlc-plugin-fluidsynth" "3.0.8-1" #2024/01/20:aur: incorporated into official vlc package (conflicts)
    #manualRemoval "manjaro-hotfixes" "2024.1-2" #2024/01/18: pkg replaced with dummy pkg https://gitlab.manjaro.org/packages/core/manjaro-hotfixes/-/commit/5c7f38e0fcfc582e5ba3a64f1527ab9e0ec952d8
    if chk_pkginstx "jdk-openjdk"; then manualRemoval "jre-openjdk" "21.u35-3"; manualRemoval "jre-openjdk-headless" "21.u35-3"; fi
    chk_pkginstx "jre-openjdk" && manualRemoval "jre-openjdk-headless" "21.u35-3" #2023/11/02: java 21 packages now conflict; keep most functional
    #chk_remoterepo "libgedit-amtk" && manualRemoval "amtk" "5.6.1-2" #2023/09/28: replaced with libgedit-amtk #not needed per https://bugs.archlinux.org/task/79851
    manualRemoval "networkmanager-fortisslvpn" "1.4.0-3" #2023/09/10: removed from arch repos
    manualRemoval "microsoft-office-web-jak" "1:2.1.2-1" #2023/06/15: removed from repos
    manualRemoval "qgpgme" "1.20.0-2" #2023/05/04: split into qgpgme-qt5 and qgpgme-qt6
    manualRemoval "adwaita-maia" "20210426-2" #2023/02/01: removed from repos
    manualRemoval "firefox-gnome-theme-maia" "20220404-1" #2023/02/01: removed from repos
    manualRemoval "gnome-shell-extension-desktop-icons-ng" "47-1" #2022/12/16: replaced with gnome-shell-extension-gtk4-desktop-icons-ng
    manualRemoval "libxfce4ui-nocsd" "4.17.0-1" #2022/12/23: removed from repos
    manualRemoval "lib32-db" "5.3.28-5" #2022/12/21: removed from arch repos
    manualRemoval "kjsembed" "5.100.0-1" #2022/12/20: removed from repos
    manualRemoval "glib2-static" "2.72.3-1" #2022-09-07: merged into glib2
    #manualRemoval "pcre-static" "8.45-1" #2022-09-07: merged into pcre (not needed per https://bugs.archlinux.org/task/75839)
    manualRemoval "wxgtk2" "3.0.5.1-3" #2022-07-14: removed from arch repos
    manualRemoval "manjaro-gdm-theme" "20210528-1"; #2022/04/23: removed from repos (conflicts with gnome>=40)
    manualRemoval "libkipi" "22.04.0-1"; #2022/04/22: moved to aur
    manualRemoval "user-manager" "5.19.5-1"; #2020/11/04: removed from repos
    manualRemoval "kvantum-theme-matchama" "20191118-1"; #2022/02/14: removed from repos, 2023/10/11: re-added/renamed
    manualRemoval "libcanberra-gstreamer" "0.30+2+gc0620e4-3"; manualRemoval "lib32-libcanberra-gstreamer" "0.30+2+gc0620e4-3" #2021/06: consolidated with lib32-/libcanberra-pulse
    manualRemoval "python2-dbus" "1.2.16-3" #2021/03: removed from dbus-python
    manualRemoval "knetattach" "5.20.5-1" #2021/01/09: merged into plasma-desktop
    manualRemoval "microsoft-office-online-jak" "1:2.0.6-1" #2020/05/31: removed from repos
    manualRemoval "ms-office-online" "20.1.0-1" #2020/06: moved to aur
    manualRemoval "manjaro-gnome-assets-19.0" "20200215-1" #2020/02/25: removed from repos
    manualRemoval "libxxf86misc"  "1.0.4-1"; manualRemoval "libdmx" "1.1.4-1" #2019/12/20: moved to aur
    chk_builtbefore "libxxf86dga" "20190317" && manualRemoval "libxxf86dga" "1.1.5-1" #2019/12/20: moved to aur
    manualRemoval "pyqt5-common" "5.13.2-1" #2019/12: removed from repos
    manualRemoval "ilmbase" "2.3.0-1" #2019/10: merged into openexr
    manualRemoval "breeze-kde4" "5.13.4-1"; manualRemoval "oxygen-kde4" "5.13.4-1"; manualRemoval "sni-qt" "0.2.6-5" #2019/05: removed from repos
    manualRemoval "libmagick" "7.0.8.41-1" #2019/04: merged into imagemagick
    manualRemoval "colord" "1.4.4-1" #2019/??: conflicts with libcolord
    #manualRemoval "libsystemd" "240.95-1" #2019/02/12: renamed to systemd-libs https://gitlab.archlinux.org/archlinux/packaging/packages/systemd/-/commit/8440896bd848b1bcb37d83575fbdb988e2a2f688
    manualRemoval "kuiserver" "5.12.5-3" #2018/06/12: removed from repos
    manualRemoval "engrampa-thunar-plugin" "1.0-2" #xfce 17.1.10 and earlier

    if ! test_online; then err[repo]=1; err_crit="repo"; break; fi

    #package replacement
    [[ "$(chk_pkgvsndiff "python-steam" "1.4.4-4")" -le 0 ]] && chk_remoterepo "python-steam-solstice" && manualRemoval "python-steam" "1.4.4-4" "python-steam-solstice" #2024/08/04: replaced with upstream fork
    [[ "$(chk_pkgvsndiff "python-vdf" "3.4-4")" -le 0 ]] && chk_remoterepo "python-vdf-solstice" && manualRemoval "python-vdf" "3.4-4" "python-vdf-solstice" #2024/08/04: replaced with upstream fork
    if chk_pkginst "pipewire-pulse" && [[ "$(chk_pkgvsndiff "pipewire-pulse" "1:1.2.2")" -lt 0 ]]; then
        if chk_pkginst "xfce4-panel"; then manualRemoval "pa-applet" "20181009-1" "xfce4-pulseaudio-plugin"
            else manualRemoval "pa-applet" "20181009-1"; fi
        manualRemoval "pulseaudio-ctl" "1.70-1"
        manualRemoval "pulseaudio-equalizer-ladspa" "3.0.2-9"
    fi #2024/07/17: pipewire-pulse 1:1.2.2 no longer provides pulseaudio
    if chk_pkginst "plasma-desktop"; then manualRemoval "systray-x-git" "0.9.7" "systray-x-kde"
        else manualRemoval "systray-x-git" "0.9.7" "systray-x-common"; fi #2023/04/17:aur: now packaged in official repos (requires legacy knotifications-renamed 2023/09/30, 0.9.6.x latest git)
    manualRemoval "dbus-x11" "1.14.4-1" "dbus" #2022/12: removed from repos
    manualRemoval "jack" "0.125.0-10" "jack2"; manualRemoval "lib32-jack" "0.125.0-10" "lib32-jack2" #2021/07/26: moved to aur
    manualRemoval "kpeoplevcard" "0.1-1" "kpeoplevcard" #requires reinstall to avoid conflicts
    manualRemoval "pamac" "7.9" "pamac" #requires reinstall to update pacman
    manualRemoval "gtk3-classic" "3.24.24-1" "gtk3"; manualRemoval "lib32-gtk3-classic" "3.24.24-1" "lib32-gtk3" #replaced around 18.0.4
    #manualRemoval "pipewire-media-session" "1:0.4.1-1" "wireplumber" #2022-05-10: replaced (rolled back)
    manualRemoval "manjaro-kde-settings-19.0 breath2-icon-themes plasma5-themes-breath2" "20200426-1" "plasma6-themes-breath manjaro-kde-settings" #2021/11: manjaro kde cleanup
    manualRemoval "manjaro-gnome-settings-19.0" "20200404-2" "manjaro-gnome-settings" #2020/04/25: replaced

    #transition packages from 'electron' to 'electronXX' when required
    if chk_pkginstx "electron" && $pcmbin -Sl|grep -E "[^ ]+ electron "|grep "installed:" >/dev/null; then
        electron_need=0; electron_prov="$(get_pkgqix "electron" "Provides"|grep -E "electron[0-9]+")"
        if [[ ! "$electron_prov" = "" ]] && chk_remoterepo "$electron_prov"; then
            for p in $(get_pkgqix "electron" "Required By"|tr '<' '\n'|tr '>' '\n'|grep -v "="); do
                if get_pkgqix "$p" "Depends On"|grep "$electron_prov" >/dev/null; then electron_need=1; break; fi; done
            if [[ "$electron_need" = "1" ]]; then
                trbl "Attempting to install new required electron package: $electron_prov"
                # shellcheck disable=SC2086
                $pcmbin -S --noconfirm --needed --asdeps electron $electron_prov 2>&1|trbl_t
            fi
        fi; unset electron_need electron_prov
    fi
fi

trbl "Updating system packages..."
for p in $(pacman -Sl | grep "\[installed"|grep "system "|grep -Eo "[^ ]*-system") ${conf_a[main_systempkgs_str]}; do
    chk_pkginstx "$p" && $pcmbin -S --needed --noconfirm "$p" 2>&1|trbl_t
    ((err[sys]+=PIPESTATUS[0])); done
if [[ ${err[sys]} -ne 0 ]]; then trbl "$co_y system packages failed to update - err:${err[sys]}"; fi

sync; trbl "Updating packages from main repos..."
trblm "$pcmbin -Su$pacdown --needed --noconfirm $manInstDep $pacignore $manOvWrt"
# shellcheck disable=SC2086
$pcmbin -Su$pacdown --needed --noconfirm $manInstDep $pacignore $manOvWrt 2>&1|trbl_t
err[repo]=${PIPESTATUS[0]}; if [[ ${err[repo]} -ne 0 ]]; then trbl "$co_r pacman exited with code ${err[repo]}"; err_crit="repo"; break; fi

# Post-update manual changes
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_manualpkg_bool]}" = "$ctrue" ]]; then
    trbl "Checking for required manual package changes..."

     #replace base-devel group with new metapackage
    if ! chk_pkginstx "base-devel"; then
        $pcmbin -Qg|grep "base-devel" >/dev/null && $pcmbin -S --noconfirm "base-devel" 2>&1|trbl_t; fi

    manualRemoval "gnome-calendar-mobile" "45.1-2" "gnome-calendar" "now" #2024/04/24: Replaced with gnome-calendar
    chk_builtbefore "qpdfview" "20200914" && manualRemoval "qpdfview" "0.4.18-2" "evince" "now" #2022-04-01: Moved to AUR
    manualRemoval "galculator-gtk2" "2.1.4-5" "galculator" "now" #2021/11/13: Replaced with galculator
    manualRemoval "gksu-polkit" "0.0.3-2" "zensu" "now" #2020/10: Removed from manjaro repos

    #Finish partial manual changes
    if [[ ! "${#installLaterDep[@]}" = "0" ]]; then while read -r p; do
        trbl "Post-update install (dependencies): $p"
        $pcmbin -S --needed --noconfirm --asdeps "$p" 2>&1|trbl_t
    done <<< "$(echo "$installLaterDep"|sed -r 's/\s+/\n/g'|grep -E "\w")"; fi
    if [[ ! "${#installLater[@]}" = "0" ]]; then while read -r p; do
        trbl "Post-update install: $p"
        $pcmbin -S --needed --noconfirm "$p" 2>&1|trbl_t
    done <<< "$(echo "$installLater"|sed -r 's/\s+/\n/g'|grep -E "\w")"; fi
    
    if [[ ! "${#manInstDep[@]}" = "0" ]]; then while read -r p; do
        trbl "Post-update mark as dep: $p"
        manualDepend "$p"
    done <<< "$(echo "$manInstDep"|sed -r 's/\s+/\n/g'|grep -E "\w")"; fi
fi

#No AUR if updated critical packages
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
[[ "$((hlpr_a[pikaur]+hlpr_a[apacman]))" = "0" ]] && break

#check if AUR pkgs need rebuild
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]]; then
    chk_pkginst "rebuild-detector" || inst_misspkg "rebuild-detector" "AUR Helper installed and enabled, and rebuilds are enabled"
    if chk_pkginst "rebuild-detector"; then
        trbl "Checking if AUR packages need rebuild..."
        for pkg in $(printf "%s\n" "${!perst_a[@]}"|grep -E "^zrbld:"); do
            if perst_isneeded "${conf_a[repair_aurrbldfail_freq]}" "${perst_a[$pkg]}"; then perst_reset "$pkg"; continue; fi
        done
        rbaur_curpkg="$(aurrebuildlist)"
        if [[ "$rbaur_curpkg" = "" ]] || [[ "$rbaur_curpkg" =~ ^[[:space:]]+$ ]]; then unset rbaur_curpkg
            else trblm "AUR Rebuilds required; AUR timestamps have been reset"; perst_reset "aur_up_date"; fi
    fi
fi

if ! perst_isneeded "${conf_a[aur_update_freq]}" "${perst_a[aur_up_date]}";  then break; fi

#check and/or fix pikaur if enabled
testpikaur(){
pikbin="pikaur"; pikarg=(-Sa --needed --noconfirm)
if [[ -f "./pikaur.py" ]]; then pikbin="python3"; pikarg=(./pikaur.py -Sa --rebuild --noconfirm); fi
pikerr=0; $pikbin "${pikarg[@]}"  "${pikpkg:-pikaur}" 2>&1|trbl_t
if [[ ! "${PIPESTATUS[0]}" = "0" ]]; then pikerr=1
    else pikaur -Q pikaur 2>&1|grep "rebuild" >/dev/null && pikerr=1
fi; return $pikerr;
}
if [ "${hlpr_a[pikaur]}" = "1" ]; then while :; do
    pikpkg="$($pcmbin -Qq pikaur)"
    if ! test_online; then hlpr_a[pikaur]=0; break; fi
    trbl "Checking if pikaur functional..."
    if testpikaur; then break; fi
    hlpr_a[pikaur]=0; trbl "$co_y AURHelper: pikaur not functioning"
    if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_pikaur01_bool]}" = "$ctrue" ]] && chk_pkginst "pikaur"; then
        trblm "Attempting to re-install ${pikpkg:-pikaur}..."
        mkdir "/tmp/xs-autmp-2delete"; if pushd "/tmp/xs-autmp-2delete"; then
            git clone https://github.com/actionless/pikaur.git; if cd pikaur; then
                if test_online && testpikaur; then hlpr_a[pikaur]=1; trblm "Successfully fixed pikaur"; fi
            fi
        sync; popd && rm -rf /tmp/xs-autmp-2delete; fi
    fi
    [[ "${hlpr_a[pikaur]}" = "0" ]] && trbl "$co_y AURHelper: pikaur will be disabled"
break; done; fi

if [[ "$((hlpr_a[pikaur]+hlpr_a[apacman]))" = "0" ]]; then
    trblm "No working AUR helpers available or not online, skipping AUR changes"; break; fi

if [[ "${conf_a[aur_1helper_str]}" = "auto" ]]; then
    if [ "${hlpr_a[pikaur]}" = "1" ]; then hlpr_a[apacman]=0; fi; fi


#Install KDE notifier dependency (if auto|desk on KDE)
if [ "${conf_a[notify_1enable_bool]}" = "$ctrue" ] && echo "${conf_a[notify_function_str]}"|grep "auto\|desk" >/dev/null &&\
chk_pkginst "plasma-desktop" && ! chk_pkginst "notify-desktop-git" && [[ "$((hlpr_a[pikaur]+hlpr_a[apacman]))" -gt "0" ]]; then
    inst_misspkg "notify-desktop-git" "Notifications enabled and KDE detected"
fi


#Update AUR packages

#rebuild AUR packages before AUR updates to minimize AUR package update failure
if [[ "${conf_a[repair_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[repair_aurrbld_bool]}" = "$ctrue" ]]; then
    if [[ ! "$rbaur_curpkg" = "" ]]; then
        trbl "Rebuilding AUR packages..."
        while [[ ! "$rbaur_curpkg" = "$rbaur_oldpkg" ]]; do
            for pkg in $rbaur_curpkg; do
                trblm "Rebuilding/reinstalling $pkg"
                if [ "${hlpr_a[pikaur]}" = "1" ]; then
                    rbcst="$(echo "${!flag_a[@]}"|grep -E "(^|,)$pkg(,|$)")"
                    [[ ! "$rbcst" = "" ]] && rbcst_flg="--mflags=${flag_a[$rbcst]}"
                    # shellcheck disable=SC2086
                    test_online && pikaur -Sa --noconfirm --rebuild $rbcst_flg "$pkg" 2>&1|trbl_t
                    unset rbcst rbcst_flg
                elif [ "${hlpr_a[apacman]}" = "1" ]; then
                    apacman -S --auronly --noconfirm "$pkg" 2>&1|trbl_t
                fi
            done
            rbaur_oldpkg="$rbaur_curpkg"; rbaur_curpkg="$(aurrebuildlist)"
        done; for pkg in $rbaur_curpkg; do perst_update "zrbld:$pkg"; done
    fi
fi; unset rbaur_curpkg rbaur_oldpkg

#AUR updates with pikaur
if [[ "${hlpr_a[pikaur]}" = "1" ]]; then
    if [[ ! "${#flag_a[@]}" = "0" ]]; then
        trbl "Updating AUR packages with custom flags [pikaur]..."
        for i in $(printf "%s\n" "${!flag_a[@]}"); do
            for j in $(echo "$i" | tr ',' ' '); do
                chk_pkginstx "$j" && custpkg+=" $j"; done
            if [[ ! "$custpkg" = "" ]]; then
                if test_online; then
                    trblm "Updating: $custpkg"
                    # shellcheck disable=SC2086
                    pikaur -Sa --needed --noconfirm --noprogressbar --mflags=${flag_a[$i]} $custpkg 2>&1|trbl_t
                    ((err[aur]+=PIPESTATUS[0])); unset custpkg
                else trbl "$co_y not online - skipping pikaur command"; unset custpkg; break; fi
            fi
        done
    fi
    perst_isneeded "${conf_a[aur_devel_freq]}" "${perst_a[aurdev_up_date]}" && devel="--devel"
    if test_online; then
        trbl "Updating remaining AUR packages [pikaur $devel]..."
        # shellcheck disable=SC2086
        pikaur -Sau$pacdown $devel --needed --noconfirm --noprogressbar $pacignore 2>&1|trbl_t
        ((err[aur]+=PIPESTATUS[0])); if [[ ${err[aur]} -eq 0 ]]; then
            perst_update "aur_up_date"
            [[ "$devel" == "--devel" ]] && perst_update "aurdev_up_date"
        else trbl "$co_y pikaur exited with error"; fi
    else err[aur]="1"; trbl "$co_y not online - skipping pikaur command"; fi
fi

#AUR updates with apacman
if [[ "${hlpr_a[apacman]}" = "1" ]]; then
    # Workaround apacman script crash ( https://github.com/lectrode/xs-update-manjaro/issues/2 )
    dummystty="/tmp/xs-dummy/stty"
    mkdir "$(dirname $dummystty)"
    echo '#!/bin/sh' >$dummystty
    echo "echo 15" >>$dummystty
    chmod +x $dummystty
    PATH=$(dirname $dummystty):$PATH; export PATH

    trbl "Updating AUR packages [apacman]..."
    # shellcheck disable=SC2086
    apacman -Su$pacdown --auronly --needed --noconfirm $pacignore 2>&1 |trbl_t
    err[aur]=${PIPESTATUS[0]}; if [[ ${err[aur]} -eq 0 ]]; then 
        perst_update "aur_up_date"; else trbl "$co_y apacman exited with error"; fi
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
            # shellcheck disable=SC2046
            $pcmbin -Rnsc $($pcmbin -Qtdq) --noconfirm 2>&1|trbl_t
            err[orphan]=${PIPESTATUS[0]}; [[ ${err[orphan]} -gt 0 ]] && trbl "$co_y pacman exited with error code ${err[orphan]}"
        fi
    fi
fi
pacclean
if [[ "$pcmbin" = "pacman-static" ]]; then $pcmbin -Rdd --noconfirm pacman-static 2>&1|trbl_t
    elif [[ ! "$pcmbin" = "pacman" ]]; then dl_clean "pacmanstatic"; fi

#Update Flatpak
if perst_isneeded "${conf_a[flatpak_update_freq]}" "${perst_a[flatpak_up_date]}"; then
    if flatpak --help >/dev/null 2>&1; then
        trbl "Updating flatpak..."
        flatpak update -y 2>&1|grep -v "█\|%"|trbl_t
        err[fpak]=${PIPESTATUS[0]}; if [[ ${err[fpak]} -eq 0 ]]; then
            perst_update "flatpak_up_date"; else trbl "$co_y flatpak exited with error code ${err[fpak]}"; fi
        if [[ "${conf_a[cln_1enable_bool]}" = "$ctrue" ]] && [[ "${conf_a[cln_flatpakorphan_bool]}" = "$ctrue" ]] && [[ "${err[fpak]}" = "0" ]]; then
            trbl "Removing unused flatpak packages..."
            flatpak uninstall --unused -y|grep -v "█\|%"|trbl_t
            err[fpakorphan]=${PIPESTATUS[0]}; if [[ ${err[fpakorphan]} -ne 0 ]]; then
                trbl "$co_y flatpak orphan removal exited with error code ${err[fpakorphan]}"; fi
        fi
    fi
fi

#Finish
trbl "Update completed, final notifications and cleanup..."
touch "${perst_d}/auto-update_termnotify.dat"

#Log error codes
[[ "$(IFS=+; echo "$((${err[*]}))")" = "0" ]] || codes="$co_y"
iconnormal; if [[ ! "$err_crit" = "" ]]; then codes="$co_r"; iconerror; fi
trbl "$(
    echo -en "$codes${co_n} error codes: "
    for i in repodb sys repo mirrors keys aur fpak orphan fpakorphan; do
        if [[ "$err_crit" = "$i" ]]; then echo -en "\033[1;31m[$i:${err[$i]}]"
        elif [[ ! "$((err[$i]+0))" = "0" ]]; then echo -en "\033[1;33m[$i:${err[$i]}]"
        else echo -en "${co_n}[$i:${err[$i]}]"; fi
    done
)"

msg="System update finished"
grep "Total Installed Size:\|new signatures:\|Total Removed Size:" "$log_f" >/dev/null || msg="$msg; no changes made"

if [ "${conf_a[notify_errors_bool]}" = "$ctrue" ]; then 
    [[ "${err[mirrors]}" -gt 0 ]] && errmsg="\n-Mirrors failed to update"
    [[ "${err[repodb]}" -gt 0 ]] && errmsg="$errmsg \n-Package databases failed to update"
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
    log_fnew="${log_f}_$(date -I)"
    mv -f "$log_f" "$log_fnew"; log_f="$log_fnew"; unset log_fnew

    activeExit=1; [[ "${conf_a[reboot_1enable_num]}" -le "0" ]] && activeExit=0
    if [[ "$activeExit" = "0" ]]; then
        degraded=0; systemctl is-system-running 2>/dev/null |grep 'running' >/dev/null || degraded=1
        iconcritical; sendall "Kernel and/or drivers were updated. Please restart your $device to finish" || degraded=1; fi
    if [[ "${conf_a[reboot_1enable_num]}" = "0" ]] && [[ "$degraded" = "1" ]]; then activeExit=1; fi

    if [ "$activeExit" = "1" ]; then
        exit_active "Kernel and/or drivers were updated.\n"
    else
        exit_passive
    fi
fi

exit 1


