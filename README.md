# mkzfsonlinux
Make ZFS on Linux for Ubuntu Live USB Ubiquity Installer<br><br>
To build a new system with ZFS on Linux for root, boot the system with Ubuntu MATE 16.04.1 Live USB into desktop environment ("Try Ubuntu"), once at the desktop, start a terminal window (CTRL-ALT-T), and type: <br><br>
`wget https://github.com/xltechasia/mkzfsonlinux/raw/master/mkzfsonlinux.sh`<br><br>
Then make the script executable:<br><br>
`chmod +x mkzfsonlinux.sh`<br><br>
To see the devices by-id on the system, use: <br><br>
`ls -la /dev/disk/by-id`<br><br>
An example build and install with mirrored drives would be: <br><br>
`sudo ./mkzfsonlinux.sh -z mirror -d ata-TOSHIBA-TR150_12AB12SJK1WU -d ata-Samsung_SSD_850_EVO_M.2_250GB_S12BNX0H123456M  --install --yes`<br><br>
The script will parse the arguments passed, and if '--yes' and '--install' are included, will proceed to **delete all data on the passed disks**.<br><br>
Before Ubiquity Installer starts, some instructions will be displayed - **do not close the terminal**, follow the instructions, and the script will continue once you are finished with the install - be sure to click **Continue Testing**.<br><br>
The order disks are provided on the cli is not important. The script will updated/install GRUB (with ZFS support) on each of the listed drives. This enables booting from any of the provided drives successfully.<br><br>
The script is based on the instructions from [ZFS on Linux Wiki "Ubuntu 16.04 Root on ZFS"](https://github.com/zfsonlinux/zfs/wiki/Ubuntu%2016.04%20Root%20on%20ZFS)<br><br>
The installation should work for any Ubuntu variant based on 16.04 or 16.10, that uses the Ubiquity installer and is available as a Live USB - Package names changed in 17.04, and the next planned update is 18.04 LTS.<br><br>
**All testing and development was done on and for Ubuntu MATE 16.04.x LTS**<br><br>
** NOTE: Any CLI Options in the script not listed below are untested, incomplete or known to have issues**<br><br>
```
NAME
    mkzfsonlinux.sh - Make ZFS on Linux for Ubuntu / Ubuntu MATE 16.04 / 16.10 Bootable USB Installer

SYNOPSIS
    mkzfsonlinux.sh [-h] [-u] -z <mirror|raidz|raidz2|zraid3> -d <disk0> [...-d <diskn>]
                    [-c <path>|--install] [--uefi] [--yes|dry]

DESCRIPTION
    mkzfsonlinux is based on https://github.com/zfsonlinux/zfs/wiki/Ubuntu%2016.04%20Root%20on%20ZFS

    *** WILL DESTROY DATA - Use at own risk - Only tested in limited scenarios with Ubuntu MATE 16.04.1 Live USB

    Builds a ZFS pool on supplied disks, runs the Ubiquity Installer, then
    copies the installation from the temporary volume (/dev/zd0) to the ZFS pool.

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
                    ** All drives passed will be reformatted - ALL partitions & data will be destroyed **
    --install   -   Create /dev/zd0 and launch Ubiquity installer after pool creation
    --yes       -   Required to execute repartitioning & ZFS pool build

If --yes is missing, after parsing options, will terminate without deleting anything

AUTHOR
    Matthew@XLTech.io

REPORTING BUGS
    https://github.com/XLTech-Asia/mkzfsonlinux/issues

COPYRIGHT
    Copyright © 2016 XLTech  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
```
