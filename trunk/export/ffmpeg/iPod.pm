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
    add_arg('multipass!',       'Enable two-pass encoding.');
    add_arg('ipod_codec=s',     'Video codec to use for iPod video (xvid or h264).');

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
        if (!$self->can_encode('mp4')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to mp4 file formats.";
        }
        if (!$self->can_encode('aac')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to aac audio.";
        }
        if (!$self->can_encode('xvid') && !$self->can_encode('h264')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to either xvid or h264 video.";
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
    # Default settings
        $self->{'defaults'}{'v_bitrate'}  = 384;
        $self->{'defaults'}{'a_bitrate'}  = 64;
        $self->{'defaults'}{'ipod_codec'} = 'xvid';
    # Verify commandline options
        if ($self->val('ipod_codec') !~ /^(?:xvid|h264)$/i) {
            die "ipod_codec must be either xvid or h264.\n";
        }
        $self->{'ipod_codec'} =~ tr/A-Z/a-z/;

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
    # Video options
        if (!$is_cli) {
        # Video codec
            while (1) {
                my $codec = query_text('Video codec (xvid or h264)?',
                                       'string',
                                       $self->{'ipod_codec'});
                if ($codec =~ /^x/) {
                    $self->{'ipod_codec'} = 'xvid';
                    last;
                }
                elsif ($codec =~ /^h/) {
                    $self->{'ipod_codec'} = 'h264';
                    last;
                }
                print "Please choose either xvid or h264\n";
            }
        # Video bitrate options
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
    # Warn about h264
        if ($self->{'ipod_codec'} eq 'h264') {
            print "Please be warned that h264 support is experimental.  I have not yet\n",
                  "been able to export a working file with h264, and would love any help\n",
                  "you can offer me in figuring out what's wrong.\n";
        }
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
        # Apparently, the -passlogfile option doesn't work for h264, so we need
        # to be aware of other processes that might be working in this directory
            if ($self->{'ipod_codec'} eq 'h264' && (-e 'x264_2pass.log.temp' || -e 'x264_2pass.log')) {
                die "ffmpeg does not allow us to specify the name of the multi-pass log\n"
                   ."file, and x264_2pass.log exists in this directory already.  Please\n"
                   ."wait for the other process to finish, or remove the stale file.\n";
            }
        # Build the common ffmpeg string
            my $ffmpeg_xtra  = ' -bufsize 65535'
                              .' -g 300 -acodec aac -async 1'
                              .' -ab '    .$self->{'a_bitrate'}
                              .' -vcodec '.$self->{'ipod_codec'}
                              .' -b '     .$self->{'v_bitrate'}
                              ." -f mp4 -title $safe_title";
        # Add the temporary files to the list
            push @tmpfiles, 'x264_2pass.log', 'x264_2pass.log.temp';
        # Back up the path and use /dev/null for the first pass
            my $path_bak = $self->{'path'};
            $self->{'path'} = '/dev/null';
        # Build the ffmpeg string
            print "First pass...\n";
            $self->{'ffmpeg_xtra'} = ' -pass 1 '.$ffmpeg_xtra;
            $self->SUPER::export($episode, '');
        # Restore the path
            $self->{'path'} = $path_bak;
        # Second Pass
            print "Final pass...\n";
            $self->{'ffmpeg_xtra'} = ' -pass 2 '.$ffmpeg_xtra;
        }
    # Single Pass
        else {
            $self->{'ffmpeg_xtra'}  = ' -bufsize 65535'
                                     .' -g 300 -acodec aac -async 50'
                                     .' -ab '    .$self->{'a_bitrate'}
                                     .' -vcodec '.$self->{'ipod_codec'}
                                     .' -b '     .$self->{'v_bitrate'}
                                     .(($self->{'vbr'})
                                       ? ' -qmin '.$self->{'quantisation'}
                                        .' -maxrate '.(2*$self->{'v_bitrate'})
                                       : '')
                                     ." -f mp4 -title $safe_title";
        }
    # Execute the (final pass) encode
        $self->SUPER::export($episode, '.mp4');
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4

