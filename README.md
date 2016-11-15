# mkzfsonlinux
Make ZFS on Linux for Ubuntu Live USB Ubiquity Installer
```
NAME
    mkzfsonlinux.sh - Make ZFS on Linux for Ubuntu / Ubuntu MATE 16.04 / 16.10 Bootable USB Installer

SYNOPSIS
    mkzfsonlinux.sh [-h] [-u] -z <mirror|raidz|raidz2|zraid3> -d <disk0> [...-d <diskn>]
                    [-c <path>|--install] [--uefi] [--yes|dry]

DESCRIPTION
    mkzfsonlinux is based on https://github.com/zfsonlinux/zfs/wiki/Ubuntu%2016.04%20Root%20on%20ZFS

    *** WILL DESTROY DATA - Use at own risk - Only tested in limited scenarios with Ubuntu MATE 16.04.1

    Builds a ZFS pool on supplied disks, run Ubiquity Installer,
    create a minimal bootable environment or copying an existing working install

OPTIONS
    -h|--help   -   Display this help & exit
    -u          -   unmount all ZFS partitions under $ZFSMNTPOINT & exit
    -z <opt>    -   ZFS RAID level to build pool
                        mirror  similiar to RAID1 - minimum of 2 drives required
                                (>2 results in all drives being a mirror of smallest drive size, ie. 4 drives <> RAID10)
                        raidz   similiar to RAID5 - n + 1 drives - minimum of 2 drives, >=3 recommended
                                maximum 1 drive failure for functioning pool
                        raidz2  similiar to RAID6 - n + 2 drives - minimum of 3 drives, >=4 recommended
                                maximum 2 drive failures for functioning pool
                        raidz3  n + 3 drives - minimum of 4 drives, >=5 recommended
                                maximum 3 drive failures for functioning pool
    -d <disk0>  -   Valid drives in /dev/disks/by-id/ to use for ZFS pool
        ...             eg. ata-Samsung_SSD_850_EVO_M.2_250GB_S24BNX0H812345M
    -d <diskn>          or  ata-ST4000DM000-2AE123_ZDH123AA
                    *** All drives passed will be reformatted - ALL partitions & data will be destroyed
    --cp <path> -   Source of working system to copy to new ZFS pool (rsync -avxHAX <path> /mnt) after pool creation
    --install   -   Create /dev/zd0 and launch Ubiquity installer after pool creation
    --uefi      -   Add partition and GRUB support for UEFI boot
    --yes       -   Required to execute repartitioning & ZFS pool build
    --dry       -   Semi-safe execution - will do as much as possible that is non-destructive. Overrides --yes
    --continue  -   Skip all steps (partitioning etc) and go straight to --install or --cp processing

If --yes or --dry are missing, after parsing options, will terminate without deleting anything
If --cp <path> and --install are mutually exclusive, passing both will cause an error
If --continue is used, the ZFS Pool, Disks and/or previously used paramaters must be exactly the same (no checking done)

AUTHOR
    Matthew@XLTech.io

REPORTING BUGS
    https://github.com/XLTech-Asia/mkzfsonlinux/issues

COPYRIGHT
    Copyright © 2016 XLTech  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
```
