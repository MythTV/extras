#!/usr/bin/perl -w
#Last Updated: 2004.09.30 (xris)
#
#  transcode.pm
#
#    routines for setting up transcode
#

package export::transcode;
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
    $cli_args{'deinterlace:s'}             = 1; # Transcode-related settings
    $cli_args{'zoom_filter:s'}             = 1; # Which zoom filter to use
    $cli_args{'crop'}                      = 1; # Crop out broadcast overscan

# This superclass defines several object variables:
#
#   use_cutlist
#   denoise
#   deinterlace
#   crop
#

# Check for transcode
    sub init_transcode {
        my $self = shift;
    # Make sure we have transcode
        $Prog{'transcode'} = find_program('transcode');
        push @{$self->{'errors'}}, 'You need transcode to use this exporter.' unless ($Prog{'transcode'});
    }

# Gather data for transcode
    sub gather_settings {
        my $self = shift;
        my $skip = shift;
    # Gather generic settings
        $self->SUPER::gather_settings($skip ? $skip - 1 : 0);
        return if ($skip);
    # Zoom Filter
        if (defined $Args{'zoom_filter'}) {
            if (!$Args{'zoom_filter'}) {
                $self->{'zoom_filter'} = 'B_spline';
            }
            elsif ($Args{'zoom_filter'} =~ /^(?:Lanczos3|Bell|Box|Mitchell|Hermite|B_spline|Triangle)$/) {
                $self->{'zoom_filter'} = $Args{'zoom_filter'};
            }
            else {
                die "Unknown zoom_filter:  $Args{'zoom_filter'}\n";
            }
        }
    # Defaults?
        $Args{'denoise'} = ''         if (defined $Args{'denoise'} && $Args{'denoise'} eq '');
        $Args{'deinterlace'}     = 'smartyuv' if (defined $Args{'deinterlace'} && $Args{'deinterlace'} eq '');
    # Noise reduction?
        $self->{'denoise'} = query_text('Enable noise reduction (slower, but better results)?',
                                                'yesno',
                                                $self->{'denoise'} ? 'Yes' : 'No');
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
        my $transcode     = '';
        my $mythtranscode = '';
    # Load nuv info
        load_finfo($episode);

    # Start the transcode command
        $transcode = 'nice -n 19 transcode'
                    .' -V'  # use YV12/I420 instead of RGB, for faster processing
                    ;
    # Not an mpeg
        unless ($episode->{'finfo'}{'is_mpeg'}) {
        # swap red/blue -- used with svcd, need to see if it's needed everywhere
            $transcode .= ' -k';
        # Set up the fifo dirs?
            if (-e "/tmp/fifodir_$$/vidout" || -e "/tmp/fifodir_$$/audout") {
                die "Possibly stale mythtranscode fifo's in /tmp/fifodir_$$/.\nPlease remove them before running nuvexport.\n\n";
            }
        # Here, we have to fork off a copy of mythtranscode (no need to use --fifosync with transcode -- it seems to do this on its own)
            $mythtranscode = "nice -n 19 mythtranscode --showprogress -p autodetect -c $episode->{channel} -s $episode->{start_time_sep} -f \"/tmp/fifodir_$$/\"";
            # let transcode handle the cutlist -- got too annoyed with the first/last frame(s) showing up no matter what I told mythtranscode
            #$mythtranscode .= ' --honorcutlist' if ($self->{'use_cutlist'});
        }
    # Figure out the input files
        if ($episode->{'finfo'}{'is_mpeg'}) {
    		$transcode .= " -i $episode->{'filename'} -x mpeg2";
        }
        else {
            $transcode .= " -i /tmp/fifodir_$$/vidout -p /tmp/fifodir_$$/audout"
                         .' -H 0 -x raw'
                         .' -g '.join('x', $episode->{'finfo'}{'width'}, $episode->{'finfo'}{'height'})
                         .' -f '.$episode->{'finfo'}{'fps'}.','
                         . (($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 3 : 4)
                         .' -n 0x1'
                         .' -e '.join(',', $episode->{'finfo'}{'audio_sample_rate'}, $episode->{'finfo'}{'audio_bits_per_sample'}, $episode->{'finfo'}{'audio_channels'})
                         ;
        }
    # Crop?
        if ($self->{'crop'}) {
            my $w = sprintf('%.0f', .02 * $episode->{'finfo'}{'width'});
            my $h = sprintf('%.0f', .02 * $episode->{'finfo'}{'height'});
            $w-- if ($w > 0 && $w % 2);    # transcode freaks out if these are odd numbers
            $h-- if ($h > 0 && $h % 2);
            $transcode .= " -j $h,$w,$h,$w" if ($h || $w);
        }
    # Use the cutlist?  (only for mpeg files -- nuv files are handled by mythtranscode)
        if ($self->{'use_cutlist'} && $episode->{'cutlist'} && $episode->{'cutlist'} =~ /\d/) {
            my @skiplist;
            foreach my $cut (split("\n", $episode->{'cutlist'})) {
                push @skiplist, (split(" - ", $cut))[0]."-".(split(" - ", $cut))[1];
            }
            $transcode .= " -J skip=\"".join(" ", @skiplist)."\"";
        }
    # Filters
        if ($self->{'zoom_filter'}) {
            $transcode .= ' --zoom_filter '.$self->{'zoom_filter'};
        }
        if ($self->{'deinterlace'}) {
            $transcode .= " -J smartyuv";
            #smartyuv|smartdeinter|dilyuvmmx
        }
        if ($self->{'denoise'}) {
            $transcode .= " -J yuvdenoise=mode=2";
        }
    # Add any additional settings from the child module
        $transcode .= ' '.$self->{'transcode_xtra'};
    # Output directory
        if (!$self->{'path'} || $self->{'path'} =~ /^\/dev\/null\b/) {
            $transcode .= ' -o /dev/null';
        }
        else {
            $transcode .= ' -o '.shell_escape($self->{'path'}.'/'.$episode->{'outfile'}.$suffix);
        }
    # Transcode pids
        my ($mythtrans_pid, $trans_pid, $mythtrans_h, $trans_h);
    # Set up and run mythtranscode?
        if ($mythtranscode) {
        # Create a directory for mythtranscode's fifo's
            mkdir("/tmp/fifodir_$$/", 0755) or die "Can't create /tmp/fifodir_$$/:  $!\n\n";
            ($mythtrans_pid, $mythtrans_h) = fork_command("$mythtranscode 2>&1 > /dev/null");
            $children{$mythtrans_pid} = 'mythtranscode' if ($mythtrans_pid);
            fifos_wait("/tmp/fifodir_$$/");
            push @tmpfiles, "/tmp/fifodir_$$", "/tmp/fifodir_$$/audout", "/tmp/fifodir_$$/vidout";
        }
    # Execute transcode
        print "Starting transcode.\n";
        ($trans_pid, $trans_h) = fork_command("$transcode 2>&1");
        $children{$trans_pid} = 'transcode' if ($trans_pid);
    # Get ready to count the frames that have been processed
        my ($frames, $fps);
        $frames = 0;
        $fps = 0.0;
        my $total_frames = $episode->{'lastgop'} ? ($episode->{'lastgop'} * (($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 12 : 15)) : 0;
	# Wait for child processes to finish
        while ((keys %children) > 0) {
            my $l;
            my $pct;
        # Show progress
            if ($frames && $total_frames) {
                $pct = sprintf('%.2f', 100 * $frames / $total_frames);
            }
            else {
                $pct = "0.00";
            }
            print "\rprocessed:  $frames of $total_frames frames ($pct\%), $fps fps ";
        # Read from the transcode handle
            while (has_data($trans_h) and $l = <$trans_h>) {
                if ($l =~ /encoding\s+frames\s+\[(\d+)-(\d+)\],\s*([\d\.]+)\s*fps,\s+EMT:\s*([\d:]+),/) {
                    $frames = int($2);
                    $fps    = $3;
                }
            }
        # Read from the mythtranscode handle?
            if ($mythtranscode && $mythtrans_pid) {
                while (has_data($mythtrans_h) and $l = <$mythtrans_h>) {
                    if ($l =~ /Processed:\s*(\d+)\s*of\s*(\d+)\s*frames\s*\((\d+)\s*seconds\)/) {
                        #$frames       = int($1);
                        $total_frames = $2;
                    }
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
    # Remove the fifodir?  (in case we're doing multipass, so we don't generate errors on the next time through)
        if ($mythtranscode) {
            unlink "/tmp/fifodir_$$/audout", "/tmp/fifodir_$$/vidout";
            rmdir "/tmp/fifodir_$$";
        }
    }


# Return true
1;

# vim:ts=4:sw=4:ai:et:si:sts=4
