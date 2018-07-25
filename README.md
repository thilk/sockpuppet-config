# SOCKPUPPET

SOCKPUPPET: A 1-file config file manager, with no CONFIG FILES FOR YOUR CONFIG FILES

Sockpuppet implements a minimalistic but serviceable approach to cluster/VM
configuration and upkeep.

Unlike other config file managers, Sockpuppet does not require making
additional config files to control it, escaping all the quotation marks and
newlines in existing config files, learning web development languages, or
reading ten pages of documentation to install it.

It uses a central mount/share/repo of config files/scripts/etc. to sync
across a cluster.  It runs as a root cronjob every 30 minutes by default.
It is literally just a bash script.

Sockpuppet makes cluster management simple.

## Who should use Sockpuppet?

Anyone tired of the complexity and overhead of e.g. Puppet, Chef, etc.

All you need to do is make a directory with the desired config files,
specify how to handle each one (in an optionally-host-dependent manner),
and run sockpuppet.sh once on each host that you want to control.

Sockpuppet will automatically update itself and its instructions from
the provided central location, indefinitely, unless uninstalled.

Currently *nix-only, for the foreseeable future.

## How to use Sockpuppet:

Simply specify a master directory containing the desired files, specify how to
handle each one at the end of the script (see section "AVAILABLE OPERATIONS"
therein, or see below), and run the script as root on each managed node in your
cluster to install it (e.g. 'sudo sockpuppet.sh').  Uninstall by passing
"uninstall" as the first cmdline arg (e.g. 'sudo sockpuppet.sh uninstall').

That's it.

### Example configuration:

Sockpuppet is configured by directly editing a copy of sockpuppet.sh itself.

First, fill in the user-specified parameters at the top of sockpuppet.sh:

```shell
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
```

Then put something like this at the bottom of sockpuppet.sh (adjust to taste):

```shell
update_file 440 root /etc/sudoers
update_file 644 root /etc/hosts

update_file 644 root /etc/ganglia/gmond.conf
update_file 644 root /etc/ganglia/gmetad.conf

hostname_like server && update_file 600 root /etc/vsftpd/vsftpd.conf

update_file 775 root /usr/bin/build_setup.sh
hostname_like media && update_file 775 root /usr/bin/mount_iso.sh

update_file 664 thilk /home/thilk/.vimrc
update_file 664 thilk /home/thilk/.muttrc

hashes_match /home/thilk/.Xauthority /root/.Xauthority \
        || ( cp /home/thilk/.Xauthority /root/.Xauthority && chown root:root /root/.Xauthority )

ensure_contains "/etc/profile" "alias cp=/usr/bin/cp"

ensure_contains_with_removal "/etc/fstab" \
    "san001:/home/share001   /mnt/nfs/san001_share001    nfs4    defaults,bg,nofail,intr,soft,retry=1000    0 0" \
    "san001_share001"

update_file 774 root /etc/rc.d/rc.local
```

So e.g., this copy of Sockpuppet will synchronize config file state as:

```
/mnt/nfs/devops/sockpuppet/master_cfg/etc/sudoers ==> /etc/sudoers
/mnt/nfs/devops/sockpuppet/master_cfg/etc/hosts ==> /etc/hosts
...
```

... and it will ensure that '/etc/profile' contains the line 'alias cp=/usr/bin/cp', and so on.

### Operations:

The most basic operation is 'update_file', which merely ensures that a
given file is copied exactly from the central mount/repo/share/etc.

Aside from that, Sockpuppet also exposes a few useful primitives for more
fine-grained control, like checking hostname patterns ('hostname_like'),
adding only specific lines to files ('ensure_contains'), and replacing
lines or eliminating duplicate lines from files ('ensure_contains_with_removal').

But ultimately, it's just a recurring bash script; do whatever you want.

### Installation:

```shell
sudo sockpuppet.sh
```

Congrats you're done.

## About:

At the time of this writing, Sockpuppet is currently being used in production
in a heterogeneous, geographically distributed Linux and FreeBSD cluster
environment with a few dozen physical servers and various VMs.  It is mainly
intended for small and mid-sized clusters, and this functionality was a good
fit for our needs.

We had seen a bit too much of, e.g., "XXXXXXXXX offers several support tiers
in addition to expert consulting services to XXXXXXXXX Enterprise customers
for optimized new implementations and complex data center transformation
projects," which essentially just amount to paying some VC-funded outfit
$XXX/hour to literally write config file for your config files.  It seemed
as though much of the complexity in this space was superfluous.

If you write any other simple, basic primitives that are useful to you, try
submitting a pull request to include them here.

