#!/bin/bash
# mkzfsonlinux.sh
# see mkzfsonlinux.sh -h for info/help

# TODO: --bootstrap option(s) to install minimal bootable environment as alternative to --cp or --install opts
# TODO: --uefi untested/unfinished
# TODO: --cp untested/unfinished..

# Constants
readonly VERSION="0.1 Alpha"
readonly TRUE=0
readonly FALSE=1

readonly REQPKGS="debootstrap gdisk zfs zfs-initramfs"

readonly UBIQUITYCMD="ubiquity"
readonly UBIQUITYARGS="gtk_ui"
readonly UBIQUITYZFSSET="ubuntu-install"
readonly UBIQUITYDEVICE="/dev/zd0"
readonly UBIQUITYPART="/dev/zd0p1"
readonly UBIQUITYMNTPOINT="/ubuntu-install"

readonly ZFSPOOL="rpool"
readonly ZFSMNTPOINT="/mnt"
# end / Constants

# Initialize / Defaults
CANEXECUTE=$FALSE
CONTINUEMODE=$FALSE

CPWRKENV=$FALSE
CPWRKENVPATH=""

DRYRUN=$FALSE
UBIQUITY=$FALSE
UEFI=$FALSE
VERBOSE=0

ZFSMINDISK=2
ZFSTYPE="mirror"
ZFSDISKCOUNT=0
ZFSDISKLIST[0]=""
# end / Initialize


show_help() {
    cat << EOF
NAME
    mkzfsonlinux.sh v$VERSION - Make ZFS on Linux for Ubuntu / Ubuntu MATE 16.04 / 16.10 Bootable USB Installer

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

EOF
} # show_help()


install_deps() {
    local APTPKGNAME
    apt-add-repository universe
    apt update
    for APTPKGNAME in $REQPKGS; do
        apt --yes install $APTPKGNAME
    done
} # install_deps()


unmount_zfs() {
    # Unmount filesystems
    printf "/nUnmounting All attached to %s & %s..." "$ZFSMNTPOINT" "$UBIQUITYMNTPOINT"

    # TODO: Change to ZFSMNTPOINT
    mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}

    # TODO: Change to UBIQUITYMNTPOINT
    mount | grep -v zfs | tac | awk '/\/ubuntu-install/ {print $3}' | xargs -i{} umount -lf {}

    zpool export $ZFSPOOL
    printf "Done\n"
} #unmount_zfs()


partition_disks() {
    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        printf "\nPartitioning %s :\n" "$ZFSDISK"

        printf "Kill all existing disk partition table...\n"
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk --zap-all /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to kill partitions on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        partprobe /dev/disk/by-id/$ZFSDISK
        printf "Done\n"

        printf "Adding common UEFI & Legacy BIOS partition...\n"
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk -a1  -n2:34:2047 -t2:EF02 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 2 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        partprobe /dev/disk/by-id/$ZFSDISK
        printf "Done\n"

        # UEFI Handling
        if [ $UEFI -eq $TRUE ]; then
            printf "Adding UEFI partition...\n"
            if [ $DRYRUN -eq $FALSE ]; then
                sgdisk -n3:1M:+512M -t3:EF00 /dev/disk/by-id/$ZFSDISK
                if [ $? -ne 0 ]; then
                    printf '\nERROR: Failed to add partition 3 UEFI on disk %s\n' "$ZFSDISK" >&2
                    exit 1
                fi
            fi
            sync # Flush writes to disk
            partprobe /dev/disk/by-id/$ZFSDISK
            printf "Done\n"
        else
            printf "UEFI Parition Creation Not Enables\n"
        fi

        # UEFI & Legacy BIOS partition
        printf "Adding ZFS Reserve partition...\n"
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk      -n9:-8M:0   -t9:BF07 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 9 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        partprobe /dev/disk/by-id/$ZFSDISK
        sync # Flush writes to disk
        printf "Done\n"

        # UEFI & Legacy BIOS partition
        printf "Adding ZFS Pool partition..."
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk      -n1:0:0     -t1:BF01 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 1 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        partprobe /dev/disk/by-id/$ZFSDISK
        printf "Done\n"
    done
} # partition_tables()


create_pool() {
    local ZPOOLPARAMS=""

    printf "\nCreating ZFS Pool %s as %s..." "$ZFSPOOL" "$ZFSTYPE"

    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        ZPOOLPARAMS="$ZPOOLPARAMS $ZFSDISK-part1"
    done

    if [ $DRYRUN -eq $FALSE ]; then
        zpool create -f -o ashift=12 \
                        -O atime=off \
                        -O canmount=off \
                        -O compression=lz4 \
                        -O normalization=formD \
                        -O mountpoint=/ \
                        -R $ZFSMNTPOINT \
                        $ZFSPOOL $ZFSTYPE $ZPOOLPARAMS
        if [ $? -ne 0 ]; then
            printf '\nERROR: Failed to create ZFS Pool\n' >&2
            exit 1
        fi
    else
        cat << EOF
zpool create -f -o ashift=12 \\
                -O atime=off \\
                -O canmount=off \\
                -O compression=lz4 \\
                -O normalization=formD \\
                -O mountpoint=/ \\
                -R $ZFSMNTPOINT \\
                $ZFSPOOL $ZFSTYPE $ZPOOLPARAMS
EOF
    fi
    printf "Done\n"
} # create_pool()


create_sets(){
    # Sets below cover most typical desktop & server scenarios

    printf "\nCreating ZFS Datasets on %s...\n" "$ZFSPOOL"

    if [ $DRYRUN -eq $FALSE ]; then
        # Filesystem Dataset
        zfs create -o canmount=off -o mountpoint=none $ZFSPOOL/ROOT

        # Root Filesystem Dataset for Ubuntu
        zfs create -o canmount=noauto -o mountpoint=/ $ZFSPOOL/ROOT/ubuntu
        zfs mount $ZFSPOOL/ROOT/ubuntu

        # Core OS Datasets
        zfs create                  -o setuid=off               $ZFSPOOL/home
        zfs create -o mountpoint=/root                          $ZFSPOOL/home/root
        zfs create -o canmount=off  -o setuid=off   -o exec=off $ZFSPOOL/var
        zfs create -o com.sun:auto-snapshot=false               $ZFSPOOL/var/cache
        zfs create                                              $ZFSPOOL/var/log
        zfs create                                              $ZFSPOOL/var/spool
        zfs create -o com.sun:auto-snapshot=false   -o exec=on  $ZFSPOOL/var/tmp

        ### Optional sets - Comment out ZFS Sets not wanted
        # If you use /srv on this system
        zfs create                                              $ZFSPOOL/srv

        # If you prefer /opt as a set on this system
        zfs create                                              $ZFSPOOL/opt

        # If this system will have games installed:
        zfs create												$ZFSPOOL/var/games

        # If this system will store local email in /var/mail:
        zfs create												$ZFSPOOL/var/mail

        # If this system will use NFS (locking):
        zfs create 	-o com.sun:auto-snapshot=false \
                    -o mountpoint=/var/lib/nfs					$ZFSPOOL/var/nfs
    fi
    printf "Done\n"
} # create_sets()


start_ubiquity() {
    cat << EOF

***********************************************************
UBIQUITY Installer is about to be launched.

*IMPORTANT* Note the following Instructions to correctly install Ubuntu;

    - Choose any options you want
    - When you get to the "Installation Type" screen and select "Something Else"
    - Listed in the drive section, you will see "$UBIQUITYDEVICE" (probably at the bottom)
    - Select it and choose "New Partition Table"
    - Select $UBIQUITYDEVICE Free Space and press the "+" button
    - Select EXT4 and mountpoint=/ In the Bootloader dropdown
    - Select "$UBIQUITYDEVICE" Press "Install Now"
    - Complete the screens for timezone and user account creation etc with your information
    - Near the end of the install, you will get an error about the bootloader not being able to be installed
    - Choose "Continue without a bootloader"
    - At the end of the install select "Continue testing"
***********************************************************
EOF
    read -n 1 -p "Press ENTER to continue..."

    printf "Preparing Environment for Ubiquity Installer..."
    zfs create -V 10G $ZFSPOOL/$UBIQUITYZFSSET
    printf "Done\n"

    printf "Launching Ubiquity Installer...\n"

    $UBIQUITYCMD $UBIQUITYARGS

    printf "Mounting Ubiquity Install Target (%s) to %s..." "$UBIQUITYDEVICE" "$UBIQUITYMNTPOINT"
    sync # Flush writes to disk
    partprobe $UBIQUITYDEVICE
    mkdir -p "$UBIQUITYMNTPOINT"
    mount "$UBIQUITYPART" "$UBIQUITYMNTPOINT"
    if [ $? -ne 0 ]; then
        printf '\nERROR: Failed to Mount Ubiquity Target Partition "%s" to "%s"\n' "$UBIQUITYPART" "$UBIQUITYMNTPOINT" >&2
        exit 1
    fi
    printf "Done\n"

    printf "Transferring Ubiquity Installation to Standard ZFS Pool...\n"
    rsync -avxHAX "$UBIQUITYMNTPOINT/." "$ZFSMNTPOINT/."
        # Options used;
        #   -a  all files, with permissions etc
        #   -v  verbose
        #   -x  stay on one filesystem
        #   -H  preserve hardlinks
        #   -A  preserve ACLs/permissions
        #   -X  preserve extended attributes
    printf "chrooting into environment to update for ZFS support...see you on the other side...\n"
    for d in proc sys dev; do mount --bind /$d $ZFSMNTPOINT/$d; done
    cat << EOF | chroot $ZFSMNTPOINT
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
apt update
apt install --yes zfs zfs-initramfs
sed -i 's|^GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="boot=zfs rpool=$ZFSPOOL bootfs=$ZFSPOOL/ROOT/ubuntu"|' /etc/default/grub
sed -i 's|^\(UUID=.*[[:space:]]/[[:space:]]\)|#\1|' /etc/fstab
exit
EOF
    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        cat << EOF | chroot $ZFSMNTPOINT
        ln -sf "/dev/$ZFSDISK-part1" "/dev/$ZFSDISK"
        update-grub
        grub-install /dev/disk/by-id/$ZFSDISK
        exit
EOF
    done
    printf "\nFinished choot process\n"

    printf "Cleaning up and Creating a snapshot before finishing up..."

    zfs snapshot $ZFSPOOL/ROOT/ubuntu@pre-reboot

    for d in proc sys dev; do umount -lf $ZFSMNTPOINT/$d; done

    printf "Done\n"

    printf "Deleting Temporary ZFS set on %s..." "$UBIQUITYDEVICE"

    zfs unmount -f $ZFSPOOL/$UBIQUITYZFSSET
    zfs destroy $ZFSPOOL/$UBIQUITYZFSSET

    printf "Done\n"

} # start_ubiquity()


copy_source() {
    rsync -avxHAX "$CPWRKENVPATH/." "$ZFSMNTPOINT/."
        # Options used;
        #   -a  all files, with permissions etc
        #   -v  verbose
        #   -x  stay on one filesystem
        #   -H  preserve hardlinks
        #   -A  preserve ACLs/permissions
        #   -X  preserve extended attributes
} # copy_source()


# main()
printf "\nmkZFSonLinux.sh v%s\n" "$VERSION"

while :; do
    case $1 in
        -h|-\?|--help)  # Call a "show_help" function to display a synopsis, then exit.
            show_help
            exit 0
            ;;
        -u|--umount)    # Unmount ZFS from /mnt
            printf "Unmounting ZFS from %s\n" "$ZFSMNTPOINT"
            unmount_zfs
            exit 0
            ;;
        --cp)           # Copy Working Environment - Takes an argument - ensuring it has been specified.
            printf "\tCOPY working environment !!!Unfinished/Untested!!!"
            shift
            if [ -n "$1" -a -d "$1" ]; then
                CPWRKENV=$TRUE
                CPWRKENVPATH="$1"
                printf " - transferring %s\n" "$CPWRKENVPATH"
                shift
            else
                printf '\nERROR: "-c" requires a valid non-empty path argument : %s\n' "$1" >&2
                exit 1
            fi
            exit 0 # Unfinished/Untested
            ;;
        --uefi)         # Support UEFI
            printf "\tUEFI support enabled\n"
            $UEFI=$TRUE
            shift
            ;;
        -v|--verbose)   # Add/Increase verbosity to output
            VERBOSE=$((VERBOSE + 1))    # Each -v argument adds 1 to verbosity.
            printf "\tVerbosity increased to %s\n" "$VERBOSE"
            shift
            ;;
        --yes)
            printf "\tEXECUTION ON - DATA will be DESTROYED\n"
            CANEXECUTE=$TRUE
            if [ $DRYRUN -eq $TRUE ]; then
                CANEXECUTE=$FALSE
                printf "\tINFO: --dry already specified and overrides --yes\n"
            fi
            shift
            ;;
        --dry)
            printf "\tDry Run Mode Active\n"
            CANEXECUTE=$FALSE
            DRYRUN=$TRUE
            shift
            ;;
        --install)      # Launch Ubiquity Installer
            printf "\tInstall Target /dev/zd0 & Ubiquity will be created & launched\n"
            UBIQUITY=$TRUE
            if [ ! -x "$(which $UBIQUITYCMD)" ]; then
                printf "/tERROR: Ubiquity Command not found (%s %s)\n" "$UBIQUITYCMD" "$UBIQUITYARGS"
                exit 1
            fi
            shift
            ;;
        -z|--zfs)       # ZFS paramenters
            printf "\tZFS pool type : "
            shift
            ZFSTYPE="$1"
            case $ZFSTYPE in
                mirror|raidz)
                    ZFSMINDISK=2
                    ;;
                raidz2)
                    ZFSMINDISK=3
                    ;;
                raidz3)
                    ZFSMINDISK=4
                    ;;
                *)  # Undefined options
                    printf '\nERROR: Unknown ZFS type : %s\n' "$1" >&2
                    exit 1
                    ;;
            esac
            printf "%s requiring a minimum of %d disks\n" "$ZFSTYPE" $ZFSMINDISK
            shift
            ;;
        -d|--disk)  # Specify a disk/drive to use for ZFS pool
            printf "\tAdding disk to pool : "
            shift
            if [ -n "$1" ]; then
                ZFSDISKCOUNT=$((ZFSDISKCOUNT + 1 )) # Adding a drive
                ZFSDISKLIST[$ZFSDISKCOUNT]="$(basename "$1")"
                if [ -L "/dev/disk/by-id/${ZFSDISKLIST[$ZFSDISKCOUNT]}" ]; then # Has to exist in disk/by-id
                    printf "Disk %d - %s : confirmed\n" $ZFSDISKCOUNT "${ZFSDISKLIST[$ZFSDISKCOUNT]}"
                else
                    printf '\nERROR: Invalid Disk By-ID Specified : %s (%s)\n' "$1" "/dev/disk/by-id/${ZFSDISKLIST[$ZFSDISKCOUNT]}" >&2
                    exit 1
                fi
            fi
            shift
            ;;
        --continue) # Set continue flag to skip partioning and ZFS pool creation
            printf "\tContinue Mode Active - Assuming Mounts, Disks, Partitions & Pools Match 100\% paramaters passed\n"
            CONTINUEMODE=$TRUE
            shift
            ;;
        --)             # End of all options.
            shift
            break
            ;;
        -?*)            # Undefined options
            printf '\nERROR: Unknown option : %s\n' "$1" >&2
            exit 1
            ;;
        *)              # Default case: If no more options then break out of the loop.
            break
    esac
done

if [ $ZFSDISKCOUNT -lt $ZFSMINDISK ]; then
    printf "\nERROR: Only %d Disks Specified - Require %d for %s ZFS Pool\n" $ZFSDISKCOUNT $ZFSMINDISK $ZFSTYPE >&2
    exit 1
fi

if [ $DRYRUN -eq $TRUE ]; then
    printf "\n >>> Dry Run Mode Selected - Execution Flag Override In Effect\n"
    CANEXECUTE=$FALSE
fi

if [ $CANEXECUTE -eq $TRUE ]; then
    printf "\n *** EXECUTION FLAG ON - DATA will be DESTROYED - CTRL-C now to terminate\n"
    read -n 1 -p "Press ENTER to continue..."
fi

if [ $DRYRUN -eq $FALSE -a $CANEXECUTE -eq $FALSE ]; then
    printf "\nExiting: --yes or --dry not specified\n"
    exit 0
fi

if [ $CONTINUEMODE -eq $FALSE ]; then
    install_deps
    unmount_zfs
    partition_disks
    create_pool
    create_sets
fi

if [ $UBIQUITY -eq $TRUE ]; then
    start_ubiquity
elif [ $CPWRKENV -eq $TRUE ]; then
    echo "O_o"
    # copy_source
fi

unmount_zfs

printf "/n/nInstallation Finished.\n"
printf "You can now proceed to reboot the system to test the new Ubuntu ZFS on Linux installation.\n\n"

exit 0

# end / main()
