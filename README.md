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

Simply specify a master directory containing the desired files, specify how to
handle each one at the end of the script (see section "AVAILABLE OPERATIONS"
therein), and run the script as root on each managed node in your cluster to
install it (e.g. 'sudo sockpuppet.sh').  Uninstall by passing "uninstall" as
the first cmdline arg (e.g. 'sudo sockpuppet.sh uninstall').  Currently
*nix-only, for the foreseeable future.

That's it.
