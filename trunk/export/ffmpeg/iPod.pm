#
# $Date$
# $Revision$
# $Author$
#
#  export::ffmpeg::iPod
#

package export::ffmpeg::iPod;
    use base 'export::ffmpeg';

# Load the myth and nuv utilities, and make sure we're connected to the database
    use nuv_export::shared_utils;
    use nuv_export::cli;
    use nuv_export::ui;
    use mythtv::db;
    use mythtv::recordings;

# Load the following extra parameters from the commandline
    add_arg('quantisation|q=i', 'Quantisation');
    add_arg('a_bitrate|a=i',    'Audio bitrate');
    add_arg('v_bitrate|v=i',    'Video bitrate');
    add_arg('multipass!',       'Enably two-pass encoding.');

    sub new {
        my $class = shift;
        my $self  = {
                     'cli'      => qr/\bipod\b/i,
                     'name'     => 'Export to iPod',
                     'enabled'  => 1,
                     'errors'   => [],
                     'defaults' => {},
                    };
        bless($self, $class);

    # Initialize the default parameters
        $self->load_defaults();

    # Verify any commandline or config file options
        die "Audio bitrate must be > 0\n" unless (!defined $self->val('a_bitrate') || $self->{'a_bitrate'} > 0);
        die "Video bitrate must be > 0\n" unless (!defined $self->val('v_bitrate') || $self->{'v_bitrate'} > 0);

    # VBR, multipass, etc.
        if ($self->val('multipass')) {
            $self->{'vbr'} = 1;
        }
        elsif ($self->val('quantisation')) {
            die "Quantisation must be a number between 1 and 31 (lower means better quality).\n" if ($self->{'quantisation'} < 1 || $self->{'quantisation'} > 31);
            $self->{'vbr'} = 1;
        }

    # Initialize and check for ffmpeg
        $self->init_ffmpeg();

    # Can we even encode ipod?
        if (!$self->can_encode('mov')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to mov file formats.";
        }
        if (!$self->can_encode('xvid')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to xvid video.";
        }
        if (!$self->can_encode('aac')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to aac audio.";
        }
    # Any errors?  disable this function
        $self->{'enabled'} = 0 if ($self->{'errors'} && @{$self->{'errors'}} > 0);
    # Return
        return $self;
    }

# Load default settings
    sub load_defaults {
        my $self = shift;
    # Load the parent module's settings
        $self->SUPER::load_defaults();
    # Default bitrates
        $self->{'defaults'}{'v_bitrate'} = 384;
        $self->{'defaults'}{'a_bitrate'} = 64;
    }

# Gather settings from the user
    sub gather_settings {
        my $self = shift;
    # Load the parent module's settings
        $self->SUPER::gather_settings();
    # Audio Bitrate
        $self->{'a_bitrate'} = query_text('Audio bitrate?',
                                          'int',
                                          $self->val('a_bitrate'));
    # VBR options
        if (!$is_cli) {
            $self->{'vbr'} = query_text('Variable bitrate video?',
                                        'yesno',
                                        $self->val('vbr'));
            if ($self->{'vbr'}) {
                $self->{'multipass'} = query_text('Multi-pass (slower, but better quality)?',
                                                  'yesno',
                                                  $self->val('multipass'));
                if (!$self->{'multipass'}) {
                    while (1) {
                        my $quantisation = query_text('VBR quality/quantisation (1-31)?',
                                                      'float',
                                                      $self->val('quantisation'));
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
            } else {
                $self->{'multipass'} = 0;
            }
        # Ask the user what video bitrate he/she wants
            $self->{'v_bitrate'} = query_text('Video bitrate?',
                                              'int',
                                              $self->val('v_bitrate'));
        }
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
    # Force to 4:3 aspect ratio
        $self->{'out_aspect'}       = 1.3333;
        $self->{'aspect_stretched'} = 1;
    # PAL or NTSC?
        my $standard = ($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 'PAL' : 'NTSC';
        $self->{'width'}   = 320;
        $self->{'height'}  = ($standard eq 'PAL') ? '288' : '240';
        $self->{'out_fps'} = ($standard eq 'PAL') ? 25    : 29.97;
    # Embed the title
        my $safe_title = shell_escape($episode->{'show_name'}.' - '.$episode->{'title'});
    # Dual pass?
        if ($self->{'multipass'}) {
        # Build the common ffmpeg string
            my $ffmpeg_xtra  = ' -b ' . $self->{'v_bitrate'}
                              .' -bufsize 65535'
                              .' -vcodec xvid -acodec aac '
                              .' -ab ' . $self->{'a_bitrate'}
                              ." -f mov -title $safe_title";
        # Add the temporary file to the list
            push @tmpfiles, "/tmp/xvid.$$.log";
        # Back up the path and use /dev/null for the first pass
            my $path_bak = $self->{'path'};
            $self->{'path'} = '/dev/null';
        # Build the ffmpeg string
            print "First pass...\n";
            $self->{'ffmpeg_xtra'}  = " -pass 1 -passlogfile '/tmp/divx.$$.log'"
                                     .$ffmpeg_xtra;
            $self->SUPER::export($episode, '');
        # Restore the path
            $self->{'path'} = $path_bak;
        # Second Pass
            print "Final pass...\n";
            $self->{'ffmpeg_xtra'}  = " -pass 2 -passlogfile '/tmp/divx.$$.log'"
                                     .$ffmpeg_xtra;
        }
    # Single Pass
        else {
            $self->{'ffmpeg_xtra'}  = ' -b ' . $self->{'v_bitrate'}
                                     .(($self->{'vbr'})
                                       ? ' -qmin '.$self->{'quantisation'}
                                        .' -qmax 31 -minrate 32'
                                        .' -maxrate '.(2*$self->{'v_bitrate'})
                                        .' -bt 32'
                                       : '')
                                     .' -vcodec xvid -acodec aac '
                                     .' -ab ' . $self->{'a_bitrate'}
                                     ." -f mov -title $safe_title";
        }
    # Execute the (final pass) encode
        $self->SUPER::export($episode, '.mov');
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4

