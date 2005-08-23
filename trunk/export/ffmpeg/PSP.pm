#
# $Date$
# $Revision$
# $Author$
#
#  export::ffmpeg::PSP
#
#   obtained and slightly modified from http://mysettopbox.tv/phpBB2/viewtopic.php?t=5030&
#

package export::ffmpeg::PSP;
    use base 'export::ffmpeg';

# Load the myth and nuv utilities, and make sure we're connected to the database
    use nuv_export::shared_utils;
    use nuv_export::cli;
    use nuv_export::ui;
    use mythtv::db;
    use mythtv::recordings;

# Load the following extra parameters from the commandline

    sub new {
        my $class = shift;
        my $self  = {
                     'cli'      => qr/\bpsp\b/i,
                     'name'     => 'Export to PSP',
                     'enabled'  => 1,
                     'errors'   => [],
                     'defaults' => {},
                    };
        bless($self, $class);

    # Initialize the default parameters
        $self->load_defaults();

    # Initialize and check for ffmpeg
        $self->init_ffmpeg();

    # Can we even encode psp?
        if (!$self->can_encode('psp')) {
            push @{$self->{'errors'}}, "Your ffmpeg installation doesn't support encoding to psp video.";
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
    # Not really anything to add
    }

# Gather settings from the user
    sub gather_settings {
        my $self = shift;
    # Load the parent module's settings
        $self->SUPER::gather_settings();
    }

    sub export {
        my $self    = shift;
        my $episode = shift;
    # Force to 4:3 aspect ratio
        $self->{'out_aspect'} = 1.3333;
        $self->{'aspect_stretched'} = 1;
    # PAL or NTSC?
        my $standard = ($episode->{'finfo'}{'fps'} =~ /^2(?:5|4\.9)/) ? 'PAL' : 'NTSC';
        $self->{'width'} = 320;
        $self->{'height'} = ($standard eq 'PAL') ? '288' : '240';
        $self->{'out_fps'} = ($standard eq 'PAL') ? 25 : 29.97;
    # Build the transcode string
        my $safe_title       = shell_escape($episode->{'show_name'}." - ".$episode->{'title'});
        $self->{'ffmpeg_xtra'}  = " -b 768"
                                 ." -ab 32 -ar 24000 -acodec aac"
                                 ." -bitexact -f psp -title $safe_title";
    # Execute the parent method
        $self->SUPER::export($episode, ".mp4");
    }

1;  #return true

# vim:ts=4:sw=4:ai:et:si:sts=4
