#!/bin/bash

# SOCKPUPPET
#
# Copyright (c) 2018 Theodore Hilk
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



# SOCKPUPPET
#
# A 1-file config file manager, with no CONFIG FILES FOR YOUR CONFIG FILES
#
# Sockpuppet implements a minimalistic but serviceable approach to cluster/VM
# configuration and upkeep.
#
# Unlike other config file managers, Sockpuppet does not require making
# additional config files to control it, escaping all the quotation marks and
# newlines in existing config files, learning web development languages, or
# reading ten pages of documentation to install it.
#
# It uses a central mount/share/repo of config files/scripts/etc. to sync
# across a cluster.  It runs as a root cronjob every 30 minutes by default.
# It is literally just a bash script.
#
# Simply specify a master directory containing the desired files, specify how to
# handle each one at the end of this script (see section "AVAILABLE OPERATIONS"
# below), and run this script as root on each managed node in your cluster to
# install it (e.g. 'sudo sockpuppet.sh').  Uninstall by passing "uninstall" as
# the first cmdline arg (e.g. 'sudo sockpuppet.sh uninstall').  Currently
# *nix-only, for the foreseeable future.
#
# That's it.



# USER-SPECIFIED PARAMETERS:

# master directory containing desired contents for config files/scripts/etc.:
# this must be accessible to each node, so use e.g. a network share or similar.
#   example:
#       CFG_MASTER_DIR="/mnt/nfs/devops/sockpuppet/master_cfg"
#
# it is suggested to use hostname-dependent conditions in each managed script
#   (e.g. in /etc/rc.d/rc.local) to permit using the same script on all nodes,
#   but alternately, you can instead use multiple different master config file
#   directories and copies of this script for different respective node types
#   (e.g. one master dir for web servers, another for compute nodes, etc.).
#   example:
#       CFG_MASTER_DIR="/mnt/nfs/devops/sockpuppet/master_cfg_-_compute_nodes"
#
CFG_MASTER_DIR="/mnt/nfs/devops/sockpuppet/master_cfg"

# interval (in minutes) to run this script:
RUN_INTERVAL_MINUTES=30

# desired location of sockpuppet.sh on managed nodes/VMs:
SOCKPUPPET_LOC="/usr/bin/sockpuppet.sh"

# END USER-SPECIFIED PARAMETERS.



# BEGIN USER IGNORE SECTION; IGNORE THIS:

# check preconditions
if [[ $RUN_INTERVAL_MINUTES -lt 2 ]]; then
    (>&2 echo "sockpuppet.sh: 'RUN_INTERVAL_MINUTES' must be at least 2 minutes" )
    exit 1
fi
if [[ ! -f "${CFG_MASTER_DIR}${SOCKPUPPET_LOC}" ]]; then
    (>&2 echo "'sockpuppet.sh' must be present at: ${CFG_MASTER_DIR}${SOCKPUPPET_LOC}" )
    exit 1
fi
for CMD in sed kill killall md5sum sleep ps cut bc cp chmod fgrep; do
    command -v $CMD >/dev/null 2>&1 || { echo >&2 "sockpuppet.sh requires command $CMD, but it's not installed.  Aborting."; exit 1; }
done

# fix interactive cp aliasing on some distros
if [[ $(which cp) =~ alias ]]; then
    alias cp=/bin/cp;
fi

# set timer to prevent accumulation of stalled jobs if something goes wrong
TIMEOUT_DELAY=$(echo "60 * ( $RUN_INTERVAL_MINUTES - 1 ) + 20" | bc)
( sleep $TIMEOUT_DELAY; if ps -p "$$" > /dev/null; then kill "$$"; sleep 5; if ps -p "$$" > /dev/null; then kill -9 "$$"; fi; fi ) &

# uninstallation logic
if [[ $1 == "uninstall" ]]; then
    sed -i "/sockpuppet.sh/d" "/root/crontab"
    killall -9 "sockpuppet.sh"
fi

# helper functions
function get_hash {
    echo $(md5sum $1 | cut -f1 -d ' ')
    return 0
}
function hashes_match {
    FILEPATH_A=$1
    FILEPATH_B=$2
    HASH_A=$(get_hash $FILEPATH_A)
    HASH_B=$(get_hash $FILEPATH_B)
    if [[ $HASH_A = $HASH_B ]]; then
        return 0
    fi
    return 1
}

# END USER IGNORE SECTION.



# AVAILABLE OPERATIONS:

# ensure a given file matches completely (copy it verbatim from master cfg dir)
function update_file {
    PERMISSIONS=$1
    OWNER=$2
    HOST_PATH=$3
    REPO_PATH="${CFG_MASTER_DIR}${HOST_PATH}"
    if [ -f $HOST_PATH ] && [ -f $REPO_PATH ]; then
        hashes_match $HOST_PATH $REPO_PATH || ( cp $REPO_PATH $HOST_PATH && chmod $PERMISSIONS $HOST_PATH && chown $OWNER:$OWNER $HOST_PATH)
    elif [ -f $REPO_PATH ]; then
        ( mkdir -p $(dirname $HOST_PATH) && cp $REPO_PATH $HOST_PATH && chmod $PERMISSIONS $HOST_PATH && chown $OWNER:$OWNER $HOST_PATH )
    fi
}

# ensure a file contains a given line
function ensure_contains {
    FILE=$1
    LINE=$2
    if ! fgrep -q "$LINE" "$FILE"; then
        sed -i '$ a '"$(echo "$LINE" | sed -e 's/[\/&]/\\&/g')" "$FILE"
        return 0
    fi
    return 1
}

# ensure a file contains a given line, removing one or more other lines first
function ensure_contains_with_removal {
    FILE=$1
    LINE=$2
    if ! fgrep -q "$LINE" "$FILE"; then
        shift
        shift
        for REMOVAL in "$@"; do
            sed -i '/'"$(echo "$REMOVAL" | sed -e 's/[\/&]/\\&/g' )"'/d' "$FILE"
        done
        sed -i '$ a '"$(echo "$LINE" | sed -e 's/[\/&]/\\&/g' )" "$FILE"
        return 0
    fi
    return 1
}

# optionally specify only a specific class of hostnames for a given operation
# example:
#   hostname_like compute_node && ensure_contains "/etc/profile" "alias run_big_job=\"some_job --big\""
function hostname_like {
    if [[ $(hostname) =~ $1 ]]; then
        return 0
    fi
    return 1
}

# END AVAILABLE OPERATIONS.



# SYSTEM-SPECIFIED OPERATIONS; DO NOT CHANGE:

# update self if needed on each run
update_file 774 root "$SOCKPUPPET_LOC"
# execute via central root crontab; update on change to RUN_INTERVAL_MINUTES
ensure_contains_with_removal '/etc/crontab' '*/'"$RUN_INTERVAL_MINUTES"' * * * * root '"$SOCKPUPPET_LOC" 'sockpuppet.sh'

# END SYSTEM-SPECIFIED OPERATIONS.



# USER-SPECIFIED OPERATIONS; EDIT THESE TO IMPLEMENT YOUR UPKEEP ROUTINES:
# 
# EXAMPLES:
#
#update_file 440 root /etc/sudoers
#update_file 644 root /etc/hosts
#
#update_file 644 root /etc/ganglia/gmond.conf
#update_file 644 root /etc/ganglia/gmetad.conf
#
#hostname_like server && update_file 600 root /etc/vsftpd/vsftpd.conf
#
#update_file 775 root /usr/bin/build_setup.sh
#hostname_like media && update_file 775 root /usr/bin/mount_iso.sh
#
#update_file 664 thilk /home/thilk/.vimrc
#update_file 664 thilk /home/thilk/.muttrc
#
#hashes_match /home/thilk/.Xauthority /root/.Xauthority || ( cp /home/thilk/.Xauthority /root/.Xauthority && chown root:root /root/.Xauthority )
#
#ensure_contains "/etc/profile" "alias cp=/usr/bin/cp"
#
#ensure_contains_with_removal "/etc/fstab" \
#    "san001:/home/share001   /mnt/nfs/san001_share001    nfs4    defaults,bg,nofail,intr,soft,retry=1000    0 0" \
#    "san001_share001"
#
#update_file 774 root /etc/rc.d/rc.local
#
# ULTIMATELY, IT'S JUST A RECURRING BASH SCRIPT; DO WHATEVER YOU WANT.



# NOTE: YOUR SPEC GOES HERE


