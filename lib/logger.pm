#!/usr/bin/perl
################################################################################
#           ASCS IPR ID : 9500
################################################################################
#
#       FILE NAME       :       logger.pm
#       DATE            :       20-January-2005
#       AUTHOR          :       Rob O'Brien
#       REFERENCE       :
#
#       COPYRIGHT       :       ATOS ORIGIN 2005
#
#       DESCRIPTION     :       Message logging and debugging.
#
################################################################################
package logger;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use File::Path;
use Time::localtime;
use Cwd;

#
# Construct a new logger object.
# param: Log file directory.
# param: Log file name.
# param: Boolean to determine whether messages should be displayed to STDOUT.
# param: Boolean to determine whether debug has been enabled.
#
sub new
{
    my $class = shift;
    my ($logDir, $logFile, $stdOut, $debug) = @_;
    my $file = init($logDir, $logFile);

    my $self = {_logFile => $file,
    	        _stdOut => $stdOut, _debug => $debug};
    bless($self, $class);
}

#
# Initialise logger object.
# param: Log file directory.
# param: Log file name.
#
sub init
{
    my ($path, $file) = @_;
    return unless $path and $file;

    my $tm = localtime;
    my $date = sprintf "%04d%02d%02d", $tm->year+1900, $tm->mon+1, $tm->mday;
    my $time = sprintf "%02d%02d%02d", $tm->hour, $tm->min, $tm->sec;

    mkpath ($path, 0) unless (-e $path);
    chdir $path;
    $path = cwd;
    
    $file = sprintf "$path/$file", "$date", "$time";
    
    my $exists = -e $file;
    
    open my $fh, '>>', $file or die "Failed to create log file $file. [$!]";
    print $fh "Logger Created: ". ctime() .".\n" unless $exists;
    return $file;
}

#
# Display debug statements (if req.d).
# param: Debug text to be displayed.
#
sub debug
{
    my ($self, $msg) = @_;
    return unless $self->{_debug};
    print "DEBUG: $msg\n";
}

# Display Debug Messages
sub printDebug
{
    my ($self, $level, $msg) = @_;
    return unless defined $self->{_debug} && $self->{_debug} >= $level;
    printf STDOUT "%s|DEBUG-%05d|%s\n", ctime(),$level,$msg;
}

#
# Wrapper to logErr. Displays a message to screen even if screen output has
# been disabled. Writes a log message.
#
sub logScreenErr
{
    my ($self, $msg) = @_;
    print "ERROR:$msg\n" unless $self->{_stdOut};
    $self->logErr($msg) if $msg;
}

#
# Wrapper used to write error messages.
# param: Error text.
#
sub logErr
{
    my ($self, $msg) = @_;

    my ($package, $filename, $line) = caller;
    $self->printDebug(1000, "logErr - PACKAGE:$package, FILE:$filename, LINE:$line");

    $self->logMsg($self, "MSG: ERROR - $msg");
    return $msg;
}

#
# Wrapper to logMsg, can return an error status is a duplicte entry exists
# in the log file.
# param: Boolean used to test for duplicate entries. If true and a duplicate
#        exists an error status will be returned.
# param: Message text.
#
sub logDuplicates
{
    my ($self, $allowDuplicates, $msg) = @_;
    my $status = 0;
    my $header = $allowDuplicates ? "Resubmit" : "Duplicate";
    
    my ($package, $filename, $line) = caller;
    $self->printDebug(1000, "logDuplicates - PACKAGE:$package, FILE:$filename, LINE:$line");
   
    if (-e $self->{_logFile} and $msg !~ /^(?:MSG|DIV)/ and !$allowDuplicates)
    {
        open my $fh, '<', $self->{_logFile} or die $self->logErr("Failed to open log file [$!].");
        #(($msg =~ /^\Q$_\E/) ? ($status = 1, last) : 0) for (<$fh>);
        ((/$msg/) ? ($status = 1, last) : 0) for (<$fh>);
        close $fh;
    }
   
    $msg = $status ? "$header - $msg" : "$msg";

    $self->logMsg($msg) if $allowDuplicates;

    return $allowDuplicates ? 0 : $status;
}

#
# Wrapper to logMsg. Displays a message to screen even if screen output has
# been disabled. Writes a log message.
#
sub logScreenMsg
{
    my ($self, $msg) = @_;
    print "$msg\n" unless $self->{_stdOut};
    $self->logMsg($msg) if $msg;
}

#
# Wrapper to logMsg. Writes a log message followed by a message divider.
#
sub logMsgDiv
{
    my ($self, $msg) = @_;
    $self->logMsg($msg) if $msg;
    $self->logMsg('DIV');
}

#
# Wrapper to logMsg. Writes a log message followed by a message divider.
#
sub logScreenDiv
{
    my ($self, $msg) = @_;
    $self->logScreenMsg($msg) if $msg;
    printf "%s\n", "-"x80;
    $self->logMsg('DIV');
}

#
# Writes a log message.
#
sub logMsg
{
    my ($self, $msg) = @_;
    $self->printDebug(1000, "logger:$msg\n");
    
    my ($package, $filename, $line) = caller;
    $self->printDebug(1000, "logMsg - PACKAGE:$package, FILE:$filename, LINE:$line");
    

    $msg = $msg eq "DIV" ? sprintf "%s\n", '-'x80 : "$msg - ".ctime()."\n";

    $self->printDebug(1000, $msg);

    return unless $self->{_logFile};
    my $rob = $self->{_logFile};
    open my $fh, '>>', $self->{_logFile} or die "Failed to open file $self->{_logFile} [$!].";
    print $fh $msg;
    print $msg if $self->{_stdOut};
    close $fh;
}

#
# Retrieve log file name.
#
sub getLogFileName
{
    my $self = shift;
    return $self->{_logFile};
}

1; # default return value.
