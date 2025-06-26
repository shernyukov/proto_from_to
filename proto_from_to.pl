#!/usr/bin/env -S perl -w
#
my $version = 'v2.5.1, 2025-06-26';
# proto_from_to 
# The script to synchronize identical folders between hosts.
# Author: Andrey Shernyukov
# andreysh@nioch.nsc.ru
#

use strict;
use Cwd;
use Cwd 'realpath';
use File::Basename;
use Term::ANSIColor qw(:constants);
use Data::Dump 'pp';
use Text::ParseWords 'shellwords';
use POSIX qw(strftime);
use Sys::Hostname;
use Getopt::Long;

########################################################################
#                      Script settings                                       


# rsync executable 
my $rsync_x = '/usr/bin/rsync';
die RED, "\nError: ", RESET, "No $rsync_x executable\n\n" unless -x $rsync_x;


# Config and log file path
my $config_file = "$ENV{HOME}/.proto_from_to.conf";
my $logfile = "$ENV{HOME}/.proto_from_to.log";

my @allARGV = ($0, @ARGV);
my @allARGV_qe = sh_quote(@allARGV);

our ($h,$help,$u,$user,$debug,$y,$yes,$r,$recursive,$nocolor,$print_config, $rsync_opt, $v, $l);

GetOptions ('h|help' => \$help,
            'u|user=s' => \$u,
            'debug' => \$debug,
            'y|yes' => \$y,
            'r|recursive' => \$recursive,
            'nocolor' => \$nocolor,
            'print_config' => \$print_config,
            'rsync_opt=s' => \$rsync_opt,
            'v|version' => \$v,
            'l|list' => \$l
            );


########################################################################
#                         Comfort                                       

# No color output trigger
if (exists($ENV{CLICOLOR}) && $ENV{CLICOLOR} == 0) {
    $ENV{ANSI_COLORS_DISABLED} = 1 if (!$ENV{CLICOLOR_FORCE});
}
$ENV{ANSI_COLORS_DISABLED} = 1 if ($nocolor);

# ctrl+c handler
$SIG{INT} = sub { die RED,"\nExecution stopped! Aborted by user", RESET,
                    "\n\n"; };

########################################################################
#                         Help                                       

print_help($version) if ($h || $help);
if ($v) { print GREEN, "proto_from_to ", CYAN, "$version\n\n", RESET; exit;} ;

print_config($config_file) if ($print_config);

########################################################################
#                         Main logic                                   

# default rsync options
my $filter ='';
if (! $rsync_opt) {
    $rsync_opt = '-avhs --delete-after --info=progress1 ';
    $filter = ' -f"- */" -f"+ *" ';
};

# Parse direction and host from script name
my ($direction, $remote_host) = parse_script_name($0);
unless ($direction && $remote_host) {
    die RED, "\nScript name must be in format [to|from]_hostname\n",
        RED, "Execution stopped!", RESET, "\n";
}
    print MAGENTA, "[DEBUG, ",__LINE__,"] \$direction = $direction\n", RESET if ($debug);
    print MAGENTA, "[DEBUG, ",__LINE__,"] \$remote_host = $remote_host\n", RESET if ($debug);

my $localhost = hostname;

## local_path variants
my $local_path = getcwd(); # for user print as is
(my $quoted_local_path) = sh_quote("$local_path/"); # for bash quoted and escaped
    print MAGENTA, "[DEBUG, ",__LINE__,"] \$local_path = $local_path\n", RESET if ($debug);
    print MAGENTA, "[DEBUG, ",__LINE__,"] \$quoted_local_path = $quoted_local_path\n", RESET if ($debug);

my ($remote_logfile, $remote_path, $remote_user) = resolve_remote_path($logfile, $config_file, $u, $local_path, $remote_host);
$remote_host="$remote_user$remote_host";
(my $quoted_remote_host) = sh_quote($remote_host); 

    print MAGENTA, "[DEBUG, ",__LINE__,"] \$remote_path = $remote_path\n", RESET if ($debug);
    print MAGENTA, "[DEBUG, ",__LINE__,"] \$remote_user = $remote_user\n", RESET if ($debug);

(my $quoted_remote_path) = sh_quote("$remote_path/"); # for bash quoted and escaped
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$quoted_remote_path = $quoted_remote_path\n", RESET if ($debug);

# list remote by rsync:
if ($l) { ls_remote($remote_host,$remote_path,$quoted_remote_path); exit;}

check_remote_path($quoted_remote_host, $remote_host, $remote_path, $quoted_remote_path) ;
show_summary($direction, $remote_host, $local_path, $remote_path);


if (@ARGV) {
        print MAGENTA, "[DEBUG, ",__LINE__,"] \@ARGV     : ", join(', ', @ARGV),"\n", RESET if ($debug);

#If there are arguments, we consider them as files and folders for now 
# we process only in the direction "to"

    if ($direction eq "to") {

        my ($Files, $Folders, $Other) = parse_ARGV();

                print MAGENTA, "[DEBUG, ",__LINE__,"] \@\$Files : ", join(', ', @$Files),   "\n", RESET if ($debug);
                print MAGENTA, "[DEBUG, ",__LINE__,"] \@\$Folders : ", join(', ', @$Folders), "\n", RESET if ($debug);
                print MAGENTA, "[DEBUG, ",__LINE__,"] \@\$Other : ", join(', ', @$Other), "\n", RESET if ($debug);

        if (@$Other) {
            print RED, "Only files and folders in the current directory",
                " are allowed as arguments!\n", RESET ;
            print RED, "Not in the current directory   ", CYAN, ": ",
                join(', ', @$Other), "\n\n", RESET;
            exit();
        }

        sync_to_remote($remote_host, $remote_path, @$Files, @$Folders) if ( @$Files || @$Folders );
    }
    elsif ($direction eq "from") {
        sync_from_remote($remote_host, $remote_path, @ARGV);
    }
    else {
    die RED, "Unknown direction!", RESET, "\n";
    }
}
# if there are no arguments then we synchronize the current folder
else {
    my @src_rsync;
    my $dest_rsync;
    
    if (! ($r || $recursive)) {
        $rsync_opt .= $filter;
        }
    if ($direction eq "to") {
            $dest_rsync="$remote_host:" . "$remote_path\/";
                print MAGENTA, "[DEBUG, ",__LINE__,"] \$dest_rsync = $dest_rsync\n", RESET if ($debug);
            push(@src_rsync, "$local_path\/");
                print MAGENTA, "[DEBUG, ",__LINE__,"] \@src_rsync = @src_rsync\n", RESET if ($debug);
    }
    elsif ($direction eq "from") {
            $dest_rsync= "$local_path\/";
                print MAGENTA, "[DEBUG, ",__LINE__,"] \$dest_rsync = $dest_rsync\n", RESET if ($debug);
            push(@src_rsync, "$remote_host:" . "$remote_path\/");
                print MAGENTA, "[DEBUG, ",__LINE__,"] \@src_rsync = @src_rsync\n", RESET if ($debug);
    }
    else {
      die "Transfer direction is undefined: $direction\n", RED, "Execution stopped!\n", RESET;
    }

        print MAGENTA, "[DEBUG, ",__LINE__,"] \$rsync_opt = $rsync_opt\n", RESET if ($debug);
    rsync_sync(\@src_rsync, $dest_rsync) ;
}


########################################################################
#                            Sub's                                     

sub parse_script_name {
    my $script = shift;
    $script =~ m{([^/]+)$};
    my $name = $1 || $0;
    
    if ($name =~ /^(to|from)_([\w.-]+)$/) {
        return ($1, $2);
    }
    return;
}

# resolve remote path if config exist 
sub resolve_remote_path {
    my ($logfile, $config_file, $u, $local_path, $remote_host) = @_;

    my $remote_path;
    my $remote_user='';
    
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$config_file = $config_file\n", RESET if ($debug);

    if (! -e $config_file) {
            print MAGENTA, "[DEBUG, ",__LINE__,"] Config file does not exist!\n", RESET if ($debug); 
        $remote_path = $local_path;
        $remote_user = "$u\@" if ($u);  
        return ($remote_path, $remote_user);
    }

    my $config = load_ini_config($config_file);
    my $host_config = $config->{$remote_host} || {};
        print MAGENTA, "\n[DEBUG, ",__LINE__,"] Host \"$remote_host\" is found in config file \n",
     RESET if ($debug) and (%{$host_config});
    my $host_profiles = $host_config->{profiles_order} || [];
        print MAGENTA, "[DEBUG, ",__LINE__,"] Available profiles for $remote_host: ",
          join(', ', @{$host_profiles}), "\n", RESET if ($debug) and (@{$host_profiles});

    if ( (!@{$host_profiles}) and ($u) ) {
        die RED, "Profile for \"$u\" on \"$remote_host\" not found in config file!", RESET, "\n";
    } elsif ( (!@{$host_profiles}) and (!$u) ){
            print MAGENTA, "[DEBUG, ",__LINE__,"] Profiles on \"$remote_host\" not found in config file. \n", RESET if ($debug);
        $remote_path = $local_path; 
        $remote_user = "";  
        return ($remote_path, $remote_user);
    }

    # remote user profile 
    $u ||= "default";
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$u = $u\n", RESET if ($debug);
    my $profile = $u;
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$profile = $profile\n", RESET if ($debug);

    if (! (grep { $_ eq $u } (@{$host_profiles}))) {
        die RED, "Profile \"$u\" for host \"$remote_host\" doesnt exist in the config file!", RESET, "\n";}
    
    my $profile_config = $host_config->{profiles}{$profile} || {};

 
    my $path_mappings = $profile_config->{path_mappings} || [];
    if ($debug) {
        my $count=1;
        foreach my $mapping (@$path_mappings) {
                    print MAGENTA, "[DEBUG, ",__LINE__,"] local_prefix$count = $mapping->{local_prefix}\n", RESET;
                    print MAGENTA, "[DEBUG, ",__LINE__,"] remote_prefix$count = $mapping->{remote_prefix}\n", RESET;
                $count++;
        }
    }

    $remote_user = "$profile_config->{user}\@" if ($profile_config->{user});
    $remote_path = apply_path_mapping($local_path, $path_mappings);
    my $remote_logfile;
    $remote_logfile = apply_path_mapping($logfile, $path_mappings);
    return ($remote_logfile, $remote_path, $remote_user) ;
}


sub apply_path_mapping {

    my ($local_path, $path_mappings) = @_;
    foreach my $mapping (@$path_mappings) {
        my ($local_prefix, $remote_prefix) = ($mapping->{local_prefix}, $mapping->{remote_prefix});
        
        # Check for potentially dangerous substitution
        if ($remote_prefix =~ /\Q$local_prefix\E/) {
            warn MAGENTA, "[DEBUG, ",__LINE__,"] Warning: remote_prefix contains local_prefix ($local_prefix)", RESET, "\n" if ($debug);
        }
        
        # Replace first occurrence
        $local_path =~ s/\Q$local_prefix\E/$remote_prefix/;
    }
    
    return $local_path;
}


sub load_ini_config {
    my $file = shift;
    open my $fh, '<', $file or die "Cannot open config: $!";
    my %config;
    my $current_host;
    my $current_profile;

        print MAGENTA, "[DEBUG, ",__LINE__,"] parsing config:\n", RESET, if ($debug); 
    while (<$fh>) {
        chomp;
        next if /^\s*($|;|#)/; # Skip blank lines and comments

        if (/^\s*\[\s*([^:]+?)\s*\]\s*$/) {  # Section [host]
            $current_host = $1;
                print MAGENTA, "\n[DEBUG, ", __LINE__,"] reading host = $current_host\n", RESET, if ($debug);
            $current_profile = undef;
            $config{$current_host} = { profiles => {} };
        } elsif (/^\s*\[\s*([^:]+):(.+?)\s*\]\s*$/) {  # Section  [host:profile]
            $current_host = $1;
            $current_profile = $2;
                print MAGENTA, "[DEBUG, ",__LINE__,"] reading profile = $current_host:$current_profile\n", RESET, if ($debug);    
 
        } elsif (/^\s*([^=]+?)\s*=\s*(.+?)\s*$/) {
            my ($key, $versionalue) = ($1, $2);

            if ($key eq 'profiles') {
                $config{$current_host}{profiles_order} = [split /\s*,\s*/, $versionalue];
                      print MAGENTA, "[DEBUG, ",__LINE__,"] reading host\'s profiles: " ,
                        join(", ", @{$config{$current_host}{profiles_order}}), "\n", RESET if ($debug);  ###
            } elsif ($key eq 'path_mappings') {
                # Split the path_mapping line into separate mappings
                my @mappings = split /\s*,\s*/, $versionalue;
                    print MAGENTA, "[DEBUG, ",__LINE__,"] reading mappings = @mappings\n", RESET, if ($debug);
                my @path_mappings;

                foreach my $mapping (@mappings) {
                    my ($local, $remote) = split /:/, $mapping;
                    push @path_mappings, {
                        local_prefix => $local,
                        remote_prefix => $remote
                    };
                }

                if ($current_profile) {
                    $config{$current_host}{profiles}{$current_profile}{path_mappings} = \@path_mappings;
                } else {
                    $config{$current_host}{path_mappings} = \@path_mappings;
                }
            } else {
                if ($current_profile) {
                    $config{$current_host}{profiles}{$current_profile}{$key} = $versionalue;
                } else {
                    $config{$current_host}{$key} = $versionalue;
                }
            }
        }
    }

    close $fh;
    return \%config;
}


sub show_summary {
    my ($direction, $remote_host, $local_path, $remote_path) = @_;
    print GREEN, "\nSynchronization Summary:\n", RESET;
    print CYAN, sprintf("%-15s: %s\n", 'Direction',   $direction), RESET;
    print CYAN, sprintf("%-15s: %s\n", 'Remote Host', "$remote_host"), RESET;
    print CYAN, sprintf("%-15s: %s\n", 'Local Path',  $local_path), RESET;
    print CYAN, sprintf("%-15s: %s\n", 'Remote Path', $remote_path), RESET;
    print "\n";
}


sub parse_ARGV {

    my @Files;
    my @Folders;
    my @Other;

    foreach (@ARGV) {
        # check 
        die RED, "Invalid path   ", CYAN, ": $_\n", RED, "Execution stopped!",
            RESET, "\n" unless -e $_ and $direction eq 'to';
        # check for files and folders in the current directory
            print MAGENTA, "[DEBUG, ",__LINE__,"] \$dirname(realpath(\$_)) = ",
            dirname(realpath($_))," for $_ \n", RESET if ($debug);
        if ( $local_path eq dirname(realpath($_)) ) {
            if ( -d $_) {
                (my $folder = $_) =~ s/\/$// ; # remove trailing slash
                push(@Folders, $folder);
            } elsif ( -f $_) {
                push(@Files, $_);
            }
        } else {
            push(@Other, $_);
        }
    }
    return (\@Files, \@Folders, \@Other);
}


# To escape special characters
sub sh_quote {
    my @qarr;
    foreach (@_) {
        my ($lq, $content, $rq) = $_ =~ /(^'?)(.*?)('?$)/;
        if ($lq) { $lq =~ s/'/\\''/; } else { $lq ="'" };
        if ($rq) { $rq =~ s/'/'\\'/; } else { $rq ="'" };
        $content =~ s/'/'\\''/g;
        push (@qarr, $lq.$content.$rq);
    }
    return @qarr;
}


sub ls_remote {
    my ($remote_host,$remote_path,$quoted_remote_path) = @_;
    my @command = ($rsync_x, '--', "$remote_host:$quoted_remote_path");
    print GREEN,"\n[$remote_host:$remote_path]\n", RESET;

    open( my $out, "-|", @command ) or die RED, "Error: $!", RESET, "\n";
    print CYAN;
    while (<$out>) { 
        if ($_ =~ m/^d.+/) {
            print BOLD BLUE, $_, RESET;
        } else {
            print CYAN, $_, RESET;
        }
    }
    close $out;
    print RESET, "\n";
}


sub check_remote_path {
    #check ssh connection and check for possible errors before synchronization by testing the path
    my ($quoted_remote_host, $remote_host, $remote_path, $quoted_remote_path) = @_;
    my $ssh_check_cmd = "ssh $quoted_remote_host \"test -d $quoted_remote_path && echo EXISTS $quoted_remote_path || echo MISSING $quoted_remote_path\" 2>&1 ";
        print MAGENTA, "[DEBUG, ",__LINE__,"] $ssh_check_cmd \n", RESET if ($debug);
    my $check_output = `$ssh_check_cmd`;
        print MAGENTA, "[DEBUG, ",__LINE__,"] $check_output", RESET if ($debug);
    my $ssh_exit_status = $? >> 8;
        print MAGENTA, "[DEBUG, ",__LINE__,"] ssh_exit_status $ssh_exit_status \n", RESET if ($debug);
    if ($ssh_exit_status == 0 && $check_output =~ /EXISTS/) {
        print GREEN, "\n[exists] ", CYAN, "$remote_host:$remote_path \n", RESET;
    } 
    elsif ($ssh_exit_status != 0) {
        die RED, "SSH check failed for $remote_host:\n$check_output", RESET, "\n";
    }
    else {
        die RED, "$remote_host: $remote_path doesn't exist and cannot be 'from'!", RESET, " \n" if ($direction eq "from");
        print RED, "[Doesn't exist!] ", CYAN, "$remote_host:$remote_path \n",
            GREEN, "Press Enter to create the directory\n", RESET;
        my $cmd = "ssh $quoted_remote_host \"mkdir -p $quoted_remote_path\"";
            print MAGENTA, "[DEBUG, ",__LINE__,"] $cmd\n", RESET if ($debug);
        <STDIN> if (!$y);
        
        system($cmd) == 0 or die RED, "Failed to create remote directory: $!", RESET, "\n";
        # Recheck
        check_remote_path($quoted_remote_host, $remote_host, $remote_path, $quoted_remote_path);
    }
}


sub is_remote_path_exists {
    #Check remote paths by ssh & test -e
    my ($quoted_remote_host, @paths) = @_;
    my $cmd = "ssh $quoted_remote_host \"";
    foreach my $path (@paths) {
        $cmd .= "test -e $path && echo EXISTS:$path || echo MISSING:$path; ";
    }
    $cmd .= "\"";
    
        print MAGENTA, "[DEBUG, ",__LINE__,"] $cmd\n", RESET if ($debug); 
    my %results;
    foreach my $line (`$cmd`) {
        chomp $line;
        my ($status, $path) = split(':', $line, 2);
        $results{$path} = ($status eq 'EXISTS');
    }
    return \%results;
}


sub sync_to_remote {
    my ($remote_host, $remote_path, @items) = @_;
    my $dest_rsync="$remote_host:$remote_path\/" ;
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$dest_rsync = $dest_rsync\n", RESET if ($debug);
    my @dest_name_qe;
    my @src_rsync;
    my $exist_warning = 0;
    foreach (@items) {
        my $dest_name = "$remote_path/$_";
            print MAGENTA, "[DEBUG, ",__LINE__,"] \$dest_name = $dest_name\n", RESET if ($debug);
        (my $dest_name_qe) = sh_quote($dest_name);
        push (@dest_name_qe, $dest_name_qe);
            print MAGENTA, "[DEBUG, ",__LINE__,"] \@dest_name_qe =", join(', ', @dest_name_qe), "\n", RESET if ($debug);
        push(@src_rsync, "$_");
    }

    my $results = is_remote_path_exists($quoted_remote_host, @dest_name_qe) ;

    my $triger = 0;
    if (%$results) {
        foreach (keys %{$results}) {
            if ($results->{$_}) {
                print RED, "File/dir exists", CYAN, ": ", m{([^/]+)$}, "\n", RESET ;
                $triger = 1;
            }
        }
        print YELLOW, "Continuing the process may lead to the file/dir being replaced! \n", RESET unless (($y) or ! ($triger));
    };

        print MAGENTA, "[DEBUG, ",__LINE__,"] \@src_rsync = @src_rsync\n", RESET if ($debug);
    rsync_sync(\@src_rsync, $dest_rsync) ;
}


sub sync_from_remote {
    my ($remote_host, $remote_path, @items) = @_;
    my $dest_rsync= "$local_path\/";
    my $src_rsync="$remote_host:$remote_path\/" ;
        print MAGENTA, "[DEBUG, ",__LINE__,"] \$src_rsync = $src_rsync\n", RESET if ($debug);
    my @src_name_qe;
    my @src_rsync;
    my $exist_warning = 0;
    my $src_name_dir;
    foreach (@items) {
        if ($_ =~ m/(^.*?)\/(.*)/) {
            $src_name_dir = $1; 
            print RED, "Nested directories not allowed, changing: ", CYAN, $_, " -> ", $src_name_dir, RESET, "\n" if $2;
        } else { $src_name_dir=$_ };
        my $src_name = "$remote_path/$src_name_dir";
            print MAGENTA, "[DEBUG, ",__LINE__,"] \$src_name = $src_name\n", RESET if ($debug);
        (my $src_name_qe) = sh_quote($src_name); 
        push (@src_name_qe, $src_name_qe);
            print MAGENTA, "[DEBUG, ",__LINE__,"] \@src_name_qe =", join(', ', @src_name_qe), "\n", RESET if ($debug);
        push(@src_rsync, "$remote_host:" . $src_name);
    }

    my $results = is_remote_path_exists($quoted_remote_host, @src_name_qe) ;


    my $triger = 0;
    if (%$results) {
        foreach (keys %{$results}) {
            if (! $results->{$_}) {
                print RED, "File/dir doesn't exists", CYAN, ": ", m{([^/]+)$}, "\n", RESET ;
                $triger = 1;
            }
        }
        die RED, "There are non-existent files!\n", RESET, "\n" if ($triger);
    };

        print MAGENTA, "[DEBUG, ",__LINE__,"] \@src_rsync = @src_rsync\n", RESET if ($debug);
    rsync_sync(\@src_rsync, $dest_rsync) ;
}



sub rsync_sync {
    my ($src_rsync, $dest_rsync) = @_;
    (my @rsync_opt_qe) = shellwords($rsync_opt);
        print MAGENTA, "[DEBUG, ",__LINE__,"] \@rsync_opt_qe: ", join(', ', @rsync_opt_qe), "\n", RESET if ($debug);

    my @dry_run_command = ($rsync_x, @rsync_opt_qe, '--dry-run', '--', @$src_rsync, $dest_rsync);
    my @command = ($rsync_x, @rsync_opt_qe, '--', @$src_rsync, $dest_rsync);
        print MAGENTA, "[DEBUG, ",__LINE__,"] @command\n", RESET if ($debug);

    open( my $out, "-|", @dry_run_command ) or die RED, "Error: $!", RESET, "\n";
        while (<$out>) { 
            if ($_ =~ s/^deleting\ //) {
                print RED, "Will be deleted", CYAN, ": ",
                    GREEN, "[$remote_host] ", CYAN, "\./$_", RESET if ($direction eq "to");
                print RED, "Will be deleted", CYAN, ": ",
                    GREEN, "[localhost] ", CYAN, "\./$_", RESET if ($direction eq "from");
            }
        }
    close $out;
    
    print YELLOW, "\nPress Enter to Synchronization\n", RESET unless ( $y || $yes );
    <STDIN> unless ( $y || $yes );
    write_log(0, $logfile, "local: $localhost:$local_path remote: $remote_host:$remote_path");
    write_log(1, $logfile, "[-Started-] ");
    print CYAN;
    system (@command) == 0  or die RED, "System `@command` failed!", RESET, "\n";
    print RESET, "\n";
    write_log(2, $logfile, "[Completed] ");
}

sub write_log {
    my ($type, $log_file, @message) = @_;
    my $timestamp = '  ';
    my $line ='';
    my $line_qe='';
 
    if ($type == 0) {
        my @message_qe = sh_quote(@message); 
        $line = $timestamp . "@message"; 
        $line_qe = $timestamp . "@message_qe";
    } elsif ($type == 1) {
        $timestamp = '[' . strftime("%Y-%m-%d %H:%M:%S", localtime) . ']';
        $line = $timestamp . "@message" . "@allARGV"; 
        $line_qe = $timestamp . "@message" . "@allARGV_qe" ;
    } elsif ($type == 2) {
        $timestamp = '[' . strftime("%Y-%m-%d %H:%M:%S", localtime) . ']';
        $line = $timestamp . "@message" . "@allARGV" . "\n"; 
        $line_qe = $timestamp . "@message" . "@allARGV_qe" . "'\n'" ;
    }

    open(my $fh, '>>', $log_file) or die RED, "Unable to write to log file $log_file: $!", RESET, "\n";
    print $fh $line, "\n";
    my $cmd = "ssh $quoted_remote_host  echo \" $line_qe >> $remote_logfile\"";
        print MAGENTA, "[DEBUG, ",__LINE__,"] $cmd\n", RESET if ($debug);
    `$cmd`;
    close($fh);
    
}


sub print_help {
    my $version = shift; 
    print GREEN, "
proto_from_to ", CYAN, $version, GREEN, "

  Usage: ", CYAN, "to_<host>|from_<host> [options] [files/dirs]", GREEN, "

SYNOPSIS:", CYAN, "
  to_<host>   [options] [file1 ...]  # Sync TO remote host 
  from_<host> [options] [file1 ...]  # Sync FROM remote host

", GREEN, "BASIC OPERATION:", CYAN, "
  Without arguments:    Sync current directory
  With file/dir args:   Sync only specified items (must be in current
                        dir)
", GREEN, "OPTIONS:", CYAN, "
  -h, -help          Show this help message
  -r, -recursive     Sync directories recursively
  -y, -yes           Skip confirmation prompts
  -u=NAME            Use specific profile from config (if exists) or use
                     for remote login \"NAME\"
  -rsync_opt         Options for rsync, 
                        defaults if no [files/dirs] and no '-r':
                            -rsync_opt='-avh -f\"- */\" -f\"+ *\" --delete --info=progress1'
                        defaults if [files/dirs] or '-r':
                            -rsync_opt='-avh --delete --info=progress1'
  -l                 List remote directory (by rsync)
  -debug             Enable debug output
  -nocolor           Disable color output
  -print_config      Show example config

", GREEN, "DESCRIPTION:", CYAN, "
  Synchronize files/directories between local and remote hosts using rsync.
  Hostname and direction is extracted from script name. 
    (e.g. 'to_hostname' → sync TO host 'hostname')
  Directory tree is preserved. if the config exists, then the profile
  \"default\" or the first profile will be used. In the config file you
  can specify mapping between paths.
  History of sync is preserved in local: $logfile
  and remotehost. 

", GREEN, "EXAMPLES:", CYAN, "
  1. Sync current dir to remote server1:
     to_server1
  
  2. Sync specific files and folders to remote server1:
     to_server1 important.txt backup/
  
  3. Sync from remote:
     from_server1 
  
  4. Force sync without confirmation:
     to_server1 -y important.txt backup/

", GREEN, "TIP: Create symlinks for hosts:", CYAN, "
  ln -s proto_from_to to_prod
  ln -s proto_from_to from_dev

  ln -s proto_from_to to_server1
  ln -s proto_from_to from_server1

", RESET;
    exit;
}


sub print_config {
    my $config_file = shift;
    print GREEN, "
The config is something like in INI-file
\"", CYAN, $config_file, GREEN, "\":", CYAN, "

# for user: $ENV{USER}\ on host: $ENV{HOSTNAME}  

# server1 conf: 
[server1]
profiles = default, backup

[server1:default]
path_mapping = /home/user1:/home/user2 

[server1:backup]
user = backup
path_mapping = /home:/backup/home , /opt:/backup/opt

# server2 conf:", GREEN,"
...

", RESET;
    exit;
}

