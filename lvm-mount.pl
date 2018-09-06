#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: lvm-mount.pl
#
#        USAGE: ./lvm-mount.pl  
#
#  DESCRIPTION: mount action for linux server used for PROD DEV mounting
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Heince Kurniawan
#       EMAIL : heince.kurniawan@itgroupinc.asia
# ORGANIZATION: IT Group Indonesia
#      VERSION: 1.0
#      CREATED: 08/29/18 17:18:11
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Carp;
use v5.10.1;

#-------------------------------------------------------------------------------
#  {Hostname}->{ACTION(mount / unmount)}->{vgname-lvname}->{mount option on fstab}
#-------------------------------------------------------------------------------
my $servers =
{
    'Heinces-MacBook-Pro.local' => 
    { 
        'mount' => 
        {  
            "/psftpvg-plvsftp"          => "/sftp:ext4:defaults 1 2",
            "/pprodlibvg-plvprodlib"    => "/prodlib:ext4:defaults,nodev 1 2",
            "/pappvg-plvapp"            => "/app:ext4:defaults,nodev 1 2",
        },
        'umount' =>  
        {
            "/udatavg-ulvprodlib"       => "/prodlib",
            "/udatavg-ulvsftp"          => "/sftp",
            "/uappvg-ulvapp"            => "/app",
        },              
    },
    'centos6'   =>
    {
        'mount'     =>
        {
            "/data1-lv_app1"    => "/app1:ext4:defaults 1 2",
            "/data1-lv_app2"    => "/app2:ext4:defaults 1 2"
        },
        'umount'     =>
        {
            "/data2_lv_app1"    => "/app1",
            "/data2_lv_app2"    => "/app2"
        },
    },
};

#-------------------------------------------------------------------------------
#  some pre-defined variables
#-------------------------------------------------------------------------------
my $dev_prefix  = '/dev/mapper';
my $path        = [];
my $hostname    = `hostname`;
chomp $hostname;

#-------------------------------------------------------------------------------
#  pre-running main code
#-------------------------------------------------------------------------------
die "server name not found in the list\n" unless $servers->{$hostname};
die "linux only\n" unless $^O eq 'linux';

#-------------------------------------------------------------------------------
#  subroutine / function flow
#-------------------------------------------------------------------------------
init_lvm();
umount();
generate_fstab();
say scalar localtime() . " - Mounting all disks based on fstab" if $ENV{ITG_DEBUG};
system "mount -a";

if ($? == 0)
{
    say scalar localtime() . " - Mount Finished" if $ENV{ITG_DEBUG};
}
else
{
    say scalar localtime() . " - Mount Failed" if $ENV{ITG_DEBUG};
    exit 1;
}

#-------------------------------------------------------------------------------
#  Subroutine start here
#-------------------------------------------------------------------------------
sub init_lvm
{
    say scalar localtime() . " - Initializing LVM Disk" if $ENV{ITG_DEBUG};
    system "pvscan && vgchange -a y";

    if ($? == 0)
    {
        say scalar localtime() . " - Initializing Done" if $ENV{ITG_DEBUG};
    }
    else
    {
        say scalar localtime() . " - Initializing Failed" if $ENV{ITG_DEBUG};
        exit 1;
    }
}

sub umount
{
    backup_fstab();

    for my $dev (keys %{$servers->{$hostname}->{umount}})
    {
        my $mountpoint = $servers->{$hostname}->{umount}->{$dev};
        push @$path, $mountpoint;

        $dev = $dev_prefix . $dev;
        say scalar localtime() . " - " . $dev . " $mountpoint" if $ENV{ITG_DEBUG};
        umount_dir($mountpoint);
    }
}

sub generate_fstab
{
    open my $fh, "<", '/etc/fstab' or die "$!\n";
    my @lines;

    while (<$fh>)
    {
        next if check_fstab_line($_);
        push @lines, $_;
    }

    close $fh;

    for my $dev (keys %{$servers->{$hostname}->{mount}})
    {
        my @fstab_info = split ':' => $servers->{$hostname}->{mount}->{$dev};
        $dev = $dev_prefix . $dev;
        my $fstab_line = "$dev\t $fstab_info[0]\t $fstab_info[1]\t $fstab_info[2]\n";
        print scalar localtime() . " - fstab line: $fstab_line" if $ENV{ITG_DEBUG};
        push @lines, $fstab_line;
    }

    open my $fstab_fh, ">>", '/etc/fstab-gen' or die "$!\n";
    for (@lines)
    {
        print scalar localtime() . " - inserting to /etc/fstab-gen $_" if $ENV{ITG_DEBUG};
        print $fstab_fh $_;
    }

    close $fstab_fh;

    system "mv -f /etc/fstab-gen /etc/fstab";

    if ($? == 0)
    {
        say scalar localtime() . " - Successfully generate /etc/fstab" if $ENV{ITG_DEBUG};
    }
    else
    {
        say scalar localtime() . " - FAILED to move generated fstab" if $ENV{ITG_DEBUG};
        exit 1;
    }
}

sub check_fstab_line
{
    my $line = shift;
    for my $dir (@$path)
    {
        say scalar localtime() . " - checking if fstab contain line $dir" if $ENV{ITG_DEBUG};

        if ($line =~ m#\s+$dir\s+#)
        {
            print scalar localtime() . " - Found line $dir on : $line" if $ENV{ITG_DEBUG};
            return 1;
        }
    }

    return 0;
}

sub backup_fstab
{
    my $fstab       = '/etc/fstab';
    my $fstab_bak   = $fstab . '-' . time;

    die "fstab not exist or zero value\n" unless -s $fstab;

    say scalar localtime() . " - backing up fstab file" if $ENV{ITG_DEBUG};
    system "cp -f $fstab $fstab_bak";

    if ($? == 0)
    {
        say scalar localtime() . " - Backup to $fstab_bak successfully" if $ENV{ITG_DEBUG};
    }
    else
    {
        say scalar localtime() . " - FAILED to backup $fstab" if $ENV{ITG_DEBUG};
        exit 1;
    }
}

sub umount_dir
{
    my $dir = shift;

    if (-d $dir)
    {
        say scalar localtime() . " - unmounting directory $dir" if $ENV{ITG_DEBUG};
        system "umount -f $dir";
        
        if ($? == 0)
        {
            say scalar localtime() . " - $dir successfully unmounted" if $ENV{ITG_DEBUG};
        }
        else
        {
            say scalar localtime() . " - FAILED to unmount $dir" if $ENV{ITG_DEBUG};
            exit 1;
        }
    }
    else
    {
        say scalar localtime() . " - SKIP unmounting directory $dir" if $ENV{ITG_DEBUG};
    }
}


