#!/usr/bin/perl -w
#Last Updated: 2004.12.26 (xris)
#
#  export::VCD
#  Maintained by Gavin Hurlbut <gjhurlbu@gmail.com>
#

package export::VCD;
    use base 'export::transcode';

# Load the myth and nuv utilities, and make sure we're connected to the database
    use nuv_export::shared_utils;
    use nuv_export::ui;
    use mythtv::db;
    use mythtv::recordings;

# Load the following extra parameters from the commandline

    sub new {
        my $class = shift;
        my $self  = {
                     'cli'             => qr/\bvcd\b/i,
                     'name'            => 'Export to VCD',
                     'enabled'         => 1,
                     'errors'          => [],
                    # Transcode-related settings
                     'denoise'         => 1,
                     'deinterlace'     => 1,
                     'crop'            => 1,
                    # VCD-specific settings
                     'split_every'     => 795,		# Split every 795 megs
                    };
        bless($self, $class);

    # Initialize and check for transcode
        $self->init_transcode();
    # Make sure that we have an mplexer
        $Prog{'mplexer'} = find_program('tcmplex', 'mplex');
        push @{$self->{'errors'}}, 'You need tcmplex or mplex to export a vcd.' unless ($Prog{'mplexer'});

    # Any errors?  disable this function
        $self->{'enabled'} = 0 if ($self->{'errors'} && @{$self->{'errors'}} > 0);
    # Return
        return $self;
    }

    sub gather_settings {
        my $self = shift;
    # Load the parent module's settings
        $self->SUPER::gather_settings();
    # Split every # megs?
        $self->{'split_every'} = query_text('Split after how many MB?',
                                            'int',
                                            $self->{'split_every'});
        $self->{'split_every'} = 795 if ($self->{'split_every'} < 1);
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
    # Load nuv info
        load_finfo($episode);
    # PAL or NTSC?
        my $size = ($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? '352x288' : '352x240';
    # Build the transcode string
        $self->{'transcode_xtra'} = " -y mpeg2enc,mp2enc -Z $size"
                                   .' -F 1 -E 44100 -b 224';
    # Add the temporary files that will need to be deleted
        push @tmpfiles, $self->get_outfile($episode, ".$$.m1v"), $self->get_outfile($episode, ".$$.mpa");
    # Execute the parent method
        $self->SUPER::export($episode, ".$$");
    # Create the split file?
        my $split_file;
        if ((-s $self->get_outfile($episode, ".$$.m2v") + -s $self->get_outfile($episode, ".$$.mpa") / 0.97 > $self->{'split_every'} * 1024 * 1024) {
            $split_file = "/tmp/nuvexport-svcd.split.$$.$self->{'split_every'}";
            open(DATA, ">$split_file") or die "Can't write to $split_file:  $!\n\n";
            print DATA "maxFileSize = $self->{'split_every'}\n";
            close DATA;
            push @tmpfiles, $split_file;
        }
    # Multiplex the streams
        my $command = "nice -n $Args{'nice'} tcmplex -m v"
                      .($split_file ? ' -F '.shell_escape($split_file) : '')
                      .' -i '.shell_escape($self->get_outfile($episode, ".$$.m1v"))
                      .' -p '.shell_escape($self->get_outfile($episode, ".$$.mpa"))
                      .' -o '.shell_escape($self->get_outfile($episode, $split_file ? '..mpg' : '.mpg'));
        system($command);
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4
