#!/usr/bin/perl -w
#Last Updated: 2005.01.26 (xris)
#
#  export::ffmpeg::SVCD
#  Maintained by Chris Petersen <mythtv@forevermore.net>
#

package export::ffmpeg::SVCD;
    use base 'export::ffmpeg';

# Load the myth and nuv utilities, and make sure we're connected to the database
    use nuv_export::shared_utils;
    use nuv_export::ui;
    use mythtv::db;
    use mythtv::recordings;

# Load the following extra parameters from the commandline
    $cli_args{'quantisation|q=i'} = 1; # Quantisation
    $cli_args{'a_bitrate|a=i'}    = 1; # Audio bitrate
    $cli_args{'v_bitrate|v=i'}    = 1; # Video bitrate

    sub new {
        my $class = shift;
        my $self  = {
                     'cli'             => qr/\bsvcd\b/i,
                     'name'            => 'Export to SVCD',
                     'enabled'         => 1,
                     'errors'          => [],
                    # Transcode-related settings
                     'denoise'         => 1,
                     'deinterlace'     => 1,
                     'crop'            => 1,
                    # SVCD-specific settings
                     'quantisation'    => 5,		# 4 through 6 is probably right...
                     'a_bitrate'       => 192,
                     'v_bitrate'       => 2500,
                    };
        bless($self, $class);

    # Initialize and check for ffmpeg
        $self->init_ffmpeg();

    # Any errors?  disable this function
        $self->{'enabled'} = 0 if ($self->{'errors'} && @{$self->{'errors'}} > 0);
    # Return
        return $self;
    }

    sub gather_settings {
        my $self = shift;
    # Load the parent module's settings
        $self->SUPER::gather_settings();
    # Ask the user what audio bitrate he/she wants
        $self->{'a_bitrate'} = $Args{'a_bitrate'} if ($Args{'a_bitrate'});
        if (!$Args{'a_bitrate'} || $Args{'confirm'}) {
            while (1) {
                my $a_bitrate = query_text('Audio bitrate?',
                                           'int',
                                           $self->{'a_bitrate'});
                if ($a_bitrate < 64) {
                    print "Too low; please choose a bitrate >= 64.\n";
                }
                elsif ($a_bitrate > 384) {
                    print "Too high; please choose a bitrate <= 384.\n";
                }
                else {
                    $self->{'a_bitrate'} = $a_bitrate;
                    last;
                }
            }
        }
    # Ask the user what video bitrate he/she wants, or calculate the max bitrate (2756 max, though we round down a bit since some dvd players can't handle the max)
    # Then again, mpeg2enc seems to have trouble with bitrates > 2500
        my $max_v_bitrate = 2742 - $self->{'a_bitrate'};
        $self->{'v_bitrate'} = $Args{'v_bitrate'} if ($Args{'v_bitrate'});
        if (!$Args{'v_bitrate'} || $Args{'confirm'}) {
            $self->{'v_bitrate'} = ($max_v_bitrate < 2500) ? 2742 - $self->{'a_bitrate'} : 2500;
            while (1) {
                my $v_bitrate = query_text('Maximum video bitrate for VBR?',
                                           'int',
                                           $self->{'v_bitrate'});
                if ($v_bitrate < 1000) {
                    print "Too low; please choose a bitrate >= 1000.\n";
                }
                elsif ($v_bitrate > $max_v_bitrate) {
                    print "Too high; please choose a bitrate <= $self->{'v_bitrate'}.\n";
                }
                else {
                    $self->{'v_bitrate'} = $v_bitrate;
                    last;
                }
            }
        }
    # Ask the user what vbr quality (quantisation) he/she wants - 2..31
        $self->{'quantisation'} = $Args{'quantisation'} if ($Args{'quantisation'});
        if (!$Args{'quantisation'} || $Args{'confirm'}) {
            while (1) {
                my $quantisation = query_text('VBR quality/quantisation (2-31)?', 'float', $self->{'quantisation'});
                if ($quantisation < 2) {
                    print "Too low; please choose a number between 2 and 31.\n";
                }
                elsif ($quantisation > 31) {
                    print "Too high; please choose a number between 2 and 31\n";
                }
                else {
                    $self->{'quantisation'} = $quantisation;
                    last;
                }
            }
        }
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
    # Load nuv info
        load_finfo($episode);
    # PAL or NTSC?
        my $standard = ($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 'PAL' : 'NTSC';
        my $res = ($standard eq 'PAL') ? '480x576' : '480x480';
    # Build the ffmpeg string
        $self->{'ffmpeg_xtra'} = ' -b ' . $self->{'v_bitrate'}
                               . ' -vcodec mpeg2video'
                               . ' -qmin ' . $self->{'quantisation'}
                               . ' -ab ' . $self->{'a_bitrate'}
                               . " -ar 44100 -acodec mp2 -s $res -f svcd";
    # Execute the parent method
        $self->SUPER::export($episode, ".mpg");
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4
