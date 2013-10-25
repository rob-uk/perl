#!/usr/bin/perl
################################################################################
#           ASCS IPR ID : 9500
################################################################################
#
#       FILE NAME       :       properties.pm
#       DATE            :       20-January-2005
#       AUTHOR          :       Rob O'Brien
#       REFERENCE       :
#
#       DESCRIPTION     :       Container for configuration properties.
#
################################################################################
package properties;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use Env;
use Data::Dumper;

#
# Construct a new properties object.
# param: Reference to a logger (for debug and logging).
# param: Location of the required properties file.
#
sub new
{
    my ($class, $logger, $propFile) = @_;
    my $prop = &loadProperties($logger, $propFile);
    my $self = {_logger => $logger, _prop => $prop};
    bless($self, $class);
}

#
# Loads preoperties from a specified file.
# param: Reference to a logger (for debug and logging).
# param: Location of the required properties file.
#
sub loadProperties
{
    my ($logger, $propFile) = @_;

    $logger->printDebug(1000, "Entered load properties");

    my $prop;

    local $/ = undef;
    open my $f, '<', $propFile or die "Missing $propFile file";
    my $propFileData = <$f>;
    close $f;

    $propFileData =~ s/#.*//g; # Remove all comments.
    $propFileData =~ s/\\\n[ \t]*//g; # Allow multiline properties.

    for (split /\n/,$propFileData)
    {
        next unless /^\s*([\.\w]+)(?:\s*[:=]\s*|\s+)(.*?)\s*$/;

        my ($key, $val) = ($1, evalVal($2));
        
        $logger->printDebug(1000, "Found Property. Key:${key}, Value:${val}");
        
        my @vals = split ',', $val;
        
        if (scalar @vals > 1)
        {
            for (@vals)
            {
                if(/^ESC\[(.*)\]$/ig)
                {
                    push @{${$prop}{$key}}, $1;
                    $logger->printDebug(1000, "Found Value. $1");
                }
                elsif (/^["']*(.*)["']*=["']*(.*)["']*$/g)
                {
                    $logger->printDebug(1000, "Found Value. Key:${1}, Value:${2}");
                    ${$prop}{$key}{$1} = $2;
                }
                elsif (/^["']*(.*)["']*$/g)
                {
                    push @{${$prop}{$key}}, $1;
                    $logger->printDebug(1000, "Found Value. ${1}");
                }
                else
                {
                    push @{${$prop}{$key}}, $_;
                    $logger->printDebug(1000, "Found Value. ${_}");
                }
            }
        }
        else
        {
            if($vals[0] && $vals[0]=~/^ESC\[(.*)\]$/ig)
            {
                ${$prop}{$key} =  $1;
                $logger->printDebug(1000, "Found Value. " .(${1} || ''));
            }
            elsif ($vals[0] && $vals[0]=~/^["']*(.*)["']*=["']*(.*)["']*$/g)
            {
                ${$prop}{$key}{$1} = $2;
                $logger->printDebug(1000, "Found Value. Key:${1}, Value:${2}");
            }
            else
            {
                ${$prop}{$key} =  $vals[0];
                $logger->printDebug(1000, "Found Value. " .(${vals[0]} || ''));
            }
        }
    }
        

    $logger->printDebug(1000, "Leaving subroutine loadProperties()");

    return $prop;
}


#
# Translates environment variables embeded in strings.
# param: The string to be translated.
#
sub evalVal
{
    my $string = shift;
    
    # Translate %VAL% into $ENV{VAL}
    # Allows ENV values to be embeded in a string.
    while($string=~/(%(.*?)%)/)
    {
        my ($x, $y) = ($1, $2);
        $ENV{$y} ? $string=~s/$x/$ENV{$y}/g : $string=~s/$x/$y/g;
    }
    
    # (depricated) Translates $VAL into $ENV{VAL}
    $string = $ENV{$1} || '' if $string =~ /\$(.*)/;

    return $string;
}

#
# Returns a value for a specified property key.
# param: Property key.
#
sub getProperty
{
    my ($self, $propKey) = @_;
    #return (keys %{$self->{_prop}{$propKey}})[0];
    return ${$self->{_prop}}{$propKey};
}

#
# Returns the first valid value from an array of property keys.
# param: Property key array.
#
sub getChainProperty
{
    return getDefaultChainProperty(@_, "");
}

#
# Returns an array of property keys that match the entered regex
#
sub matchPropertyKey
{
    my ($self, $keyRegex) = @_;
    my $prop = $self->{_prop};

    my @propKeys;

    /$keyRegex/ ? push(@propKeys, $_) : 0 for keys %{$prop};

    return sort @propKeys;
}

#
# Returns a value for a specified property key.
# param: Property key.
#
sub getPropertyAsArray
{
    my ($self, $propKey) = @_;
    my @ret;
    my $type = ref($self->{_prop}{$propKey});

    if ($type eq "SCALAR" || $type eq "")
    {
      push @ret, $self->{_prop}{$propKey};
    }

    if ($type eq "HASH")
    {
      @ret = keys %{$self->{_prop}{$propKey}};
    }

    if ($type eq "ARRAY")
    {
      @ret = @{$self->{_prop}{$propKey}};
    }

    return @ret;
}

#
# Returns a value for a specified property key.
# param: Property key.
#
sub getPropertyAsHash
{
    my ($self, $propKey) = @_;
    return %{$self->{_prop}{$propKey}};
}

#
# Returns a value for a specified property key or a default value.
# param: Property key.
# param: The value to be used as a default.
#
sub getDefaultProperty
{
    my ($self, $propKey, $defaultValue) = @_;
    my $value = $self->getProperty($propKey);
    return $value ? $value : $defaultValue;
}

#
# Returns the first valid value from an array of property keys, or the default
# value if the property doesn't exist.
# param: Property key array.
# param: The value to be used as a default.
#
sub getDefaultChainProperty
{
    my $self = shift;
    my $defaultValue = pop;
    my @propKey = @_;
    my $value;
    
    for (@propKey)
    {
        $value = $self->getProperty($_);
        last if $value;
    }

    return $value ? $value : $defaultValue;
}

sub getTranslatedProperty
{
    my ($self, $propKey) = @_;
    return $ENV($self->{_prop}) || '';
}

#
# Adds a property key/value to the properties object.
# param: Property key.
# param: Property value.
#
sub setProperty
{
    my ($self, $propKey, $propValue) = @_;
    $self->{_logger}->printDebug(1000, "Set property [$propKey => $propValue]");
    ${$self->{_prop}}{$propKey} = $propValue;
}

#
# Adds a property key/array_value to the properties object.
# param: Property key.
# param: Property array_value.
#
sub setPropertyAsArray
{
    my ($self, $propKey, @propValue) = @_;
    $self->{_logger}->printDebug(1000, "Set property [$propKey => @propValue]");
    ${$self->{_prop}}{$propKey} = \@propValue;
}

#
# Dumps a string version of the properties object.
#
sub toString
{
    my $self = shift;
    my $prop = $self->{_prop};
    my $propStr = "Properties:\n";
    $propStr .= Data::Dumper->Dump([\$self->{_prop}],[q($self->{_prop})]);
    return $propStr;
}

1;
