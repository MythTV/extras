#!/usr/bin/perl -w
#Last Updated: 2005.02.06 (xris)
#
#  export::ffmpeg::XviD
#  Maintained by Chris Petersen <mythtv@forevermore.net>
#

package export::ffmpeg::XviD;
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
    $cli_args{'multipass'}        = 1; # Two-pass encoding

    sub new {
        my $class = shift;
        my $self  = {
                     'cli'             => qr/\bxvid\b/i,
                     'name'            => 'Export to XviD',
                     'enabled'         => 1,
                     'errors'          => [],
                    # Transcode-related settings
                     'noise_reduction' => 1,
                     'deinterlace'     => 1,
                     'crop'            => 1,
                    # VBR-specific settings
                     'vbr'             => 1,
                     'quantisation'    => 6,        # 4 through 6 is probably right...
                    # Other video options
                     'a_bitrate'       => 128,
                     'v_bitrate'       => 960,      # Remember, quantisation overrides video bitrate
                     'width'           => 624,
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
    # Audio Bitrate
        if ($Args{'a_bitrate'}) {
            $self->{'a_bitrate'} = $Args{'a_bitrate'};
            die "Audio bitrate must be > 0\n" unless ($Args{'a_bitrate'} > 0);
        }
        else {
            $self->{'a_bitrate'} = query_text('Audio bitrate?',
                                              'int',
                                              $self->{'a_bitrate'});
        }
    # VBR options
        if ($Args{'quantisation'}) {
            die "Quantisation must be a number between 1 and 31 (lower means better quality).\n" if ($Args{'quantisation'} < 1 || $Args{'quantisation'} > 31);
            $self->{'quantisation'} = $Args{'quantisation'};
            $self->{'vbr'}          = 1;
        }
        elsif (!$is_cli) {
            $self->{'vbr'} = query_text('Variable bitrate video?',
                                        'yesno',
                                        $self->{'vbr'} ? 'Yes' : 'No');
            if ($self->{'vbr'}) {
                while (1) {
                    my $quantisation = query_text('VBR quality/quantisation (1-31)?', 'float', $self->{'quantisation'});
                    if ($quantisation < 1) {
                        print "Too low; please choose a number between 1 and 31.\n";
                    }
                    elsif ($quantisation > 31) {
                        print "Too high; please choose a number between 1 and 31\n";
                    }
                    else {
                        $self->{'quantisation'} = $quantisation;
                        last;
                    }
                }
            }
        }
    # Ask the user what audio and video bitrates he/she wants
        if ($Args{'v_bitrate'}) {
            die "Video bitrate must be > 0\n" unless ($Args{'v_bitrate'} > 0);
            $self->{'v_bitrate'} = $Args{'v_bitrate'};
        }
        elsif (!$self->{'vbr'}) {
            # make sure we have v_bitrate on the commandline
            $self->{'v_bitrate'} = query_text('Video bitrate?',
                                              'int',
                                              $self->{'v_bitrate'});
        }
    # Query the resolution
        $self->query_resolution();
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
    # Make sure we have finfo
        load_finfo($episode);
    # Build the ffmpeg string
        $self->{'ffmpeg_xtra'} = ' -b ' . $self->{'v_bitrate'}
                               . (($self->{'vbr'}) ?
                                 " -qmin $self->{'quantisation'} -qmax 31" : '')
                               . ' -vcodec xvid'
                               . ' -ab ' . $self->{'a_bitrate'}
                               . ' -acodec mp3'
                               . " -s $self->{'width'}x$self->{'height'}";
        $self->SUPER::export($episode, '.avi');
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4
