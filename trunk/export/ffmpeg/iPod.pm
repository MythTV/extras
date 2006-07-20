#!/usr/bin/perl -w
#
# ffmpeg-based iPod video module for nuvexport.
#
# Many thanks to cartman in #ffmpeg, and for the instructions at
# http://rob.opendot.cl/index.php?active=3&subactive=1
#
# @url       $URL$
# @date      $Date$
# @version   $Revision$
# @author    $Author$
# @copyright Silicon Mechanics
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
            if ($self->{'ffmpeg_vers'} eq 'svn') {
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
            }
            else {
                $self->{'ipod_codec'} = 'xvid';
                print "Using the mpeg4 codec (h.264 ipod encoding requires the svn version of ffmpeg.)\n";
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
    # Complain about h264
        if ($self->{'ipod_codec'} eq 'h264' && $self->{'ffmpeg_vers'} ne 'svn') {
            die "h.264 ipod encoding requires the svn version of ffmpeg.\n";
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
        $self->{'out_fps'} = ($standard eq 'PAL') ? 25    : 23.976023976;
    # Embed the title
        my $safe_title = shell_escape($episode->{'show_name'}.' - '.$episode->{'title'});
    # Build the common ffmpeg string
        my $ffmpeg_xtra  = ' -vcodec '.$self->{'ipod_codec'}
                          .' -b '     .$self->{'v_bitrate'}
                          ." -title $safe_title";
    # Dual pass?
        if ($self->{'multipass'}) {
        # Apparently, the -passlogfile option doesn't work for h264, so we need
        # to be aware of other processes that might be working in this directory
            if ($self->{'ipod_codec'} eq 'h264' && (-e 'x264_2pass.log.temp' || -e 'x264_2pass.log')) {
                die "ffmpeg does not allow us to specify the name of the multi-pass log\n"
                   ."file, and x264_2pass.log exists in this directory already.  Please\n"
                   ."wait for the other process to finish, or remove the stale file.\n";
            }
        # Add the temporary files to the list
            push @tmpfiles, 'x264_2pass.log',
                            'x264_2pass.log.temp',
                            'ffmpeg2pass-0.log';
        # Back up the path and use /dev/null for the first pass
            my $path_bak = $self->{'path'};
            $self->{'path'} = '/dev/null';
        # A couple of extra options required for h.264
            if ($self->{'ipod_codec'} eq 'h264') {
                $ffmpeg_xtra .= ' -vcodec h264'
                               .' -level 13'
                               .' -flags +loop -chroma 1'
                               .' -keyint_min 25 -sc_threshold 40 -i_quant_factor 0.71'
                               .' -bit_rate_tolerance '.$self->{'v_bitrate'}
                               .' -rc_max_rate 768000 -rc_buffer_size 2000000'
                               .' -rc_eq \'blurCplx^(1-qComp)\''
                               .' -coder 0 -me_range 16 -gop_size 250';
            }
            else {
                $ffmpeg_xtra .= ' -mbd 2 -flags +4mv+trell -aic 2'
                               .' -cmp 2 -subcmp 2';
            }
        # Build the ffmpeg string
            print "First pass...\n";
            $self->{'ffmpeg_xtra'} = ' -pass 1 '
                                    .' -acodec copy'
                                    .$ffmpeg_xtra
                                    .' -qcompress 0.6 -qmin 10 -qmax 51 -max_qdiff 4'
                                    .' -f mp4';
            if ($self->{'ipod_codec'} eq 'h264') {
                $self->{'ffmpeg_xtra'} .= ' -partitions 0 -flags2 0 -me_method 5'
                                         .' -subq 1 -trellis 0 -refs 1';
            }
            $self->SUPER::export($episode, '');
        # Restore the path
            $self->{'path'} = $path_bak;
        # Second Pass
            print "Final pass...\n";
            $self->{'ffmpeg_xtra'} = ' -pass 2 '
                                    .$ffmpeg_xtra;
            if ($self->{'ipod_codec'} eq 'h264') {
                $self->{'ffmpeg_xtra'} .= ' -partitions partp8x8+partb8x8'
                                         .' -flags2 +mixed_refs -me_method 8'
                                         .' -subq 7 -trellis 2 -refs 5';
            }
        }
    # Single Pass
        else {
            if ($self->{'ipod_codec'} eq 'h264') {
                $ffmpeg_xtra .= ' -vcodec h264'
                               .' -flags +loop -chroma 1 -partitions partp8x8+partb8x8'
                               .' -flags2 +mixed_refs -me_method 8 -subq 7 -trellis 2'
                               .' -refs 5 -coder 0 -me_range 16 -gop_size 250'
                               .' -keyint_min 25 -sc_threshold 40 -i_quant_factor 0.71'
                               .' -bit_rate_tolerance '.$self->{'v_bitrate'}
                               .' -rc_max_rate 768000 -rc_buffer_size 2000000'
                               .' -rc_eq \'blurCplx^(1-qComp)\''
                               .' -level 13';
            }
            else {
                $ffmpeg_xtra .= ' -mbd 2 -flags +4mv+trell -aic 2'
                               .' -cmp 2 -subcmp 2';
            }
            $self->{'ffmpeg_xtra'} = ($self->{'vbr'}
                                      ? ' -qcompress 0.6 -qmin '.$self->{'quantisation'}
                                       .' -qmax 51 -max_qdiff 4'
                                       .' -maxrate '.(2*$self->{'v_bitrate'})
                                      : '')
                                    .$ffmpeg_xtra;
        }
    # Don't forget the audio, etc.
        $self->{'ffmpeg_xtra'} .= ' -acodec aac -ar 48000 -async 1'
                                 .' -ab '.$self->{'a_bitrate'};
    # Execute the (final pass) encode
        $self->SUPER::export($episode, '.mp4');
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4

