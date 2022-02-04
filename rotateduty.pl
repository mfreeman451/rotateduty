#!/usr/local/bin/perl5
# $Id: rotateduty,v 1.7 1999/11/01 16:56:39 mfs Exp $
# $Log: rotateduty,v $
# Revision 1.7  1999/11/01 16:56:39  mfs
# Changed recipients of notification email b/ of staffing changes. -mfs
#
# Revision 1.5  1999/06/16 21:37:27  syseng
# Change path to the main storage dir to /home/syseng/data/emergency. -mfs
#
# Revision 1.4  1999/06/16 20:59:13  syseng
# Just changed who gets email notification for the telecom stuff. -mfs
#
# Revision 1.3  1999/06/03 12:24:27  syseng
# Fixed who gets the email message. -mfs
#
# For each group that needs to be updated, the script will shift everyone in
# the group 'up' one row in the group's cf file.  The person on top goes to the
# end and the new person on top is the person now on call.

# Needed modules.
use File::Copy;

# The cf files.
$mainpath  = '/home/syseng/data/emergency';
$confext   = 'cf';
$scriptext = 'txt';
$myname = `basename`;
chomp($myname);
%cfs  = ('syseng','mfs@shore.net',
	 'telecom','cjl@shore.net,richb@shore.net',
	 'netops','twd@shore.net,breed@shore.net',
         'webops','brianmac@shore.net');

# Check argument, if any.
if ($#ARGV > 0) {
    die "$myname: Accepts either 1 or no arguments only\n";
} elsif ($#ARGV == 0) {
    if (grep(/^$ARGV[0]$/,keys(%cfs),'all')) {
	$argument = $ARGV[0];
    } else {
	die "$myname: Not a legal Shore.Net Group:  $ARGV[0]\n";
    }
} else {
    $argument = 'all';
}


# If $argument is 'all', then attempt to update the cf files for each group in
# the %cfs array.  If an argument is given, and it's a legal group, only update
# that group.
if ($argument ne 'all') {
    &fixcf("$argument");
} else {
    my($group);
    foreach $group (keys(%cfs)) {
	&fixcf("$group");
    }
}

# Done
exit 0;

# Subroutines
# Open the group cf file and put the members into an array.  Since the first
# member of each array was the person oncall, we shift them off.  Then
# open the cf file for writing and print the contents of the array to the file
# and finish up by putting the person who was on call as the last entry.  Now
# the first person in the cf file is the person who is now on call.
sub fixcf {
    my($group)  = shift(@_);
    my($file)   = "$mainpath/$group.$confext";
    my($target) = "$mainpath/$group.$scriptext";
    if (open(CF,"$file")) {
        my(@members);
        while(<CF>) {
            chomp;
            push(@members,"$_");
        }
        close(CF);
        my($newlast) = shift(@members);

        if (open(CF,">$file")) {
            foreach (@members) {
                print(CF "$_\n");
            }
            print(CF "$newlast\n");
            close(CF);
	    if (copy("$file","$target")) {
		chown('60001','41',"$target");
		chmod(0644,"$target");
		&sendmail("$group");
	    } else {
		warn "Copy of $file to $target failed.  Please fix asap.\n";
	    }
        } else {
            warn "Cannot open $file for writing: $!\n";
            warn "Not able to update cf file for $group\n";
        }
    } else {
        warn "Cannot open $file for reading: $!\n";
        warn "Not able to rotate oncall duty for $group\n";
    }
}

sub sendmail {
    my($group) = shift(@_);
    my($recip);
    $mailprog = "/usr/lib/sendmail -t";
    $mailto = $cfs{"$group"};
    if (open(MAIL,"|$mailprog")) {
	print MAIL "From: syseng\@shore.net\n";
	print MAIL "To: $mailto\n";
	print MAIL "Subject: Oncall rotation succeeded\n\n";
	print MAIL "The rotation looks as follows.  The group member at the top is the one on call.\n\n";
        if (open(CF,"$mainpath/$group.$confext")) {
	    while(<CF>) {
		print MAIL "\t$_";
	    }
	    close(CF);
	} else {
	    print MAIL "Unable to open conf $mainpath/$group.$confext: $!\n";
	}
	close(MAIL);
    } else {
	warn "Cannot send email for $group: $!\n";
    }
}
