#!/usr/bin/perl -w
#Last Updated: 2004.10.02 (xris)
#
#  ffmpeg.pm
#
#    routines for setting up ffmpeg
#    Maintained by Gavin Hurlbut <gjhurlbu@gmail.com>
#

package export::ffmpeg;
    use base 'export::generic';

    use export::generic;

    use Time::HiRes qw(usleep);
    use POSIX;

    use nuv_export::shared_utils;
    use nuv_export::ui;
    use mythtv::recordings;

# Load the following extra parameters from the commandline
    $cli_args{'deinterlace:s'}             = 1; # Deinterlace video
    $cli_args{'denoise|noise_reduction:s'} = 1; # Enable noise reduction
    $cli_args{'crop'}                      = 1; # Crop out broadcast overscan

# This superclass defines several object variables:
#
#   path        (defined by generic)
#   use_cutlist (defined by generic)
#   denoise
#   deinterlace
#   crop
#

# Check for ffmpeg
    sub init_ffmpeg {
        my $self = shift;
        my $audioonly = (shift or 0);
    # Make sure we have ffmpeg
        $Prog{'ffmpeg'} = find_program('ffmpeg');
        push @{$self->{'errors'}}, 'You need ffmpeg to use this exporter.' unless ($Prog{'ffmpeg'});
        $self->{'audioonly'} = $audioonly;
    }

# Gather data for ffmpeg
    sub gather_settings {
        my $self = shift;
        my $skip = shift;
    # Gather generic settings
        $self->SUPER::gather_settings($skip ? $skip - 1 : 0);
        return if ($skip);
    # Defaults?
        $Args{'noise_reduction'} = ''         if (defined $Args{'noise_reduction'} && $Args{'noise_reduction'} eq '');
        $Args{'deinterlace'}     = '' if (defined $Args{'deinterlace'} && $Args{'deinterlace'} eq '');
    # Noise reduction?
        $self->{'noise_reduction'} = query_text('Enable noise reduction (slower, but better results)?',
                                                'yesno',
                                                $self->{'noise_reduction'} ? 'Yes' : 'No');
    # Deinterlace video?
        $self->{'deinterlace'} = query_text('Enable deinterlacing?',
                                            'yesno',
                                            $self->{'deinterlace'} ? 'Yes' : 'No');

    # Crop video to get rid of broadcast padding
        if ($Args{'crop'}) {
            $self->{'crop'} = 1;
        }
        else {
            $self->{'crop'} = query_text('Crop broadcast overscan (2% border)?',
                                         'yesno',
                                         $self->{'crop'} ? 'Yes' : 'No');
        }
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
        my $suffix  = (shift or '');
    # Init the commands
        my $ffmpeg        = '';
        my $mythtranscode = '';

    # Load nuv info
        load_finfo($episode);

    # Set up the fifo dirs?
        if (-e "/tmp/fifodir_$$/vidout" || -e "/tmp/fifodir_$$/audout") {
            die "Possibly stale mythtranscode fifo's in /tmp/fifodir_$$/.\nPlease remove them before running nuvexport.\n\n";
        }

    # Here, we have to fork off a copy of mythtranscode (no need to use --fifosync with transcode -- it seems to do this on its own)
        $mythtranscode = "nice -n $Args{'nice'} mythtranscode --showprogress -p autodetect -c $episode->{channel} -s $episode->{start_time_sep} -f \"/tmp/fifodir_$$/\"";
        $mythtranscode .= ' --honorcutlist' if ($self->{use_cutlist});

        my $videofifo = "/tmp/fifodir_$$/vidout";
        my $videotype = 'rawvideo';
        my $crop_w;
        my $crop_h;

        if ($self->{'crop'}) {
            $crop_w = sprintf('%.0f', .02 * $episode->{'finfo'}{'width'});
            $crop_h = sprintf('%.0f', .02 * $episode->{'finfo'}{'height'});
            # keep crop numbers even
            $crop_w-- if ($crop_w > 0 && $crop_w % 2);
            $crop_h-- if ($crop_h > 0 && $crop_h % 2);
        }

        if ($self->{'audioonly'}) {
            $ffmpeg .= "cat /tmp/fifodir_$$/vidout > /dev/null | ";
        }
        else {
        # Do noise reduction
            if ($self->{'noise_reduction'}) {
                $ffmpeg .= "nice -n $Args{'nice'} ffmpeg -f rawvideo ";
                $ffmpeg .= "-s " . $episode->{'finfo'}{'width'} . "x" . $episode->{'finfo'}{'height'};
                $ffmpeg .= " -r " . $episode->{'finfo'}{'fps'};
                $ffmpeg .= " -i /tmp/fifodir_$$/vidout -f yuv4mpegpipe -";
                $ffmpeg .= " 2> /dev/null | ";
                $ffmpeg .= "nice -n $Args{'nice'} yuvdenoise -F -r 16";
                if ($self->{'crop'}) {
                    $ffmpeg .= " -b $crop_w,$crop_h,-$crop_w,-$crop_h";
                }
                $ffmpeg .= " 2> /dev/null | ";
                $videofifo = "-";
                $videotype = "yuv4mpegpipe";
            }
        }

    # Start the ffmpeg command
        $ffmpeg .= "nice -n $Args{'nice'} ffmpeg -y -f s16le";
        $ffmpeg .= " -ar " . $episode->{'finfo'}{'audio_sample_rate'};
        $ffmpeg .= " -ac " . $episode->{'finfo'}{'audio_channels'};
        $ffmpeg .= " -i /tmp/fifodir_$$/audout";
        if (!$self->{'audioonly'}) {
            $ffmpeg .= " -f $videotype";
            $ffmpeg .= " -s " . $episode->{'finfo'}{'width'} . "x" . $episode->{'finfo'}{'height'};
            $ffmpeg .= " -r " . $episode->{'finfo'}{'fps'};
            $ffmpeg .= " -i $videofifo";

        # Filters
            if ($self->{'deinterlace'}) {
                $ffmpeg .= " -deinterlace";
            }

            if ($self->{'crop'}) {

                $ffmpeg .= " -croptop $crop_h -cropbottom $crop_h";
                $ffmpeg .= " -cropleft $crop_w -cropright $crop_w";
            }
        }

    # Add any additional settings from the child module
        $ffmpeg .= ' '.$self->{'ffmpeg_xtra'};

    # Output directory
        if (!$self->{'path'} || $self->{'path'} =~ /^\/dev\/null\b/) {
            $ffmpeg .= ' /dev/null';
        }
        else {
            $ffmpeg .= " " . shell_escape($self->{'path'}.'/'.$episode->{'outfile'}.$suffix);
        }
    # ffmpeg pids
        my ($mythtrans_pid, $ffmpeg_pid, $mythtrans_h, $ffmpeg_h);

    # Create a directory for mythtranscode's fifo's
        mkdir("/tmp/fifodir_$$/", 0755) or die "Can't create /tmp/fifodir_$$/:  $!\n\n";
        ($mythtrans_pid, $mythtrans_h) = fork_command("$mythtranscode 2>&1 > /dev/null");
        $children{$mythtrans_pid} = 'mythtranscode' if ($mythtrans_pid);
        fifos_wait("/tmp/fifodir_$$/");
        push @tmpfiles, "/tmp/fifodir_$$", "/tmp/fifodir_$$/audout", "/tmp/fifodir_$$/vidout";

    # Execute ffmpeg
        print "Starting ffmpeg.\n";
        ($ffmpeg_pid, $ffmpeg_h) = fork_command("$ffmpeg 2>&1");
        $children{$ffmpeg_pid} = 'ffmpeg' if ($ffmpeg_pid);

    # Get ready to count the frames that have been processed
        my ($frames, $fps, $start);
        $frames = 0;
        $fps = 0.0;
        $start = time();
        my $total_frames = $episode->{'lastgop'} ? ($episode->{'lastgop'} * (($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 12 : 15)) : 0;
	# Wait for child processes to finish
        while ((keys %children) > 0) {
            my $l;
            my $pct;
        # Show progress
            if ($frames && $total_frames) {
                $pct = sprintf('%.2f', 100 * $frames / $total_frames);
                $fps = ($frames * 1.0) / (time() - $start);
            }
            else {
                $pct = "0.00";
            }
            printf "\rprocessed:  $frames of $total_frames frames ($pct\%%), %6.2f fps ", $fps;

        # Read from the ffmpeg handle
            while (has_data($ffmpeg_h) and $l = <$ffmpeg_h>) {
                if ($l =~ /frame=\s*(\d+)/) {
                    $frames = int($1);
                }
            }
        # Read from the mythtranscode handle?
            while (has_data($mythtrans_h) and $l = <$mythtrans_h>) {
                if ($l =~ /Processed:\s*(\d+)\s*of\s*(\d+)\s*frames\s*\((\d+)\s*seconds\)/) {
                    if ($self->{'audioonly'}) {
                        $frames       = int($1);
                    }
                    $total_frames = $2;
                }
            }
        # The pid?
            $pid = waitpid(-1, &WNOHANG);
            if ($children{$pid}) {
                print "\n$children{$pid} finished.\n";
                delete $children{$pid};
                ##### do something here to track the time for the next process to die.
                ##### If we wait too long, something obviously ended too early.
            }
        # Sleep for 1/10 second so we don't go too fast and annoy the cpu
            usleep(100000);
        }
    # Remove the fifodir?
        unlink "/tmp/fifodir_$$/audout", "/tmp/fifodir_$$/vidout";
        rmdir "/tmp/fifodir_$$";
    }


# Return true
1;

# vim:ts=4:sw=4:ai:et:si:sts=4
