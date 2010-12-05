#! /usr/bin/perl
# vim:ts=4:sw=4:ai:et:si:sts=4
use strict;
use warnings;
use Apache2::Const -compile => qw(M_POST HTTP_METHOD_NOT_ALLOWED);
use CGI;
use JSON;
use Mail::Send;

my $debug = 0;

my $r = shift;

unless ($r->method_number == Apache2::Const::M_POST) {
    $r->allowed($r->allowed | (1 << Apache2::Const::M_POST));
    $r->status(Apache2::Const::HTTP_METHOD_NOT_ALLOWED);
    return;
}

$r->content_type('text/html');
$r->print();

# Payload is described at http://help.github.com/post-receive-hooks/
my $json    = JSON->new->utf8;
my $payload = CGI->new->param('payload');
$payload    = $json->decode($payload);

if ( $debug ) {
    open FH, ">", "/tmp/dump.json";
    print FH $json->pretty->encode($payload);
    close FH;
}

my $repository = $payload->{"repository"}->{"name"};
my $branch = $payload->{"ref"};
$branch =~ s/^refs\/.*?\///;

# These maybe should go into a config file later
my %headers = (
    "From"          => 'MythTV <noreply@mythtv.org>',
    "To"            => 'mythtv-commits@mythtv.org',
    "Reply-to"      => 'mythtv-dev@mythtv.org',
    "X-Repository"  => $repository,
);

foreach my $commit ( @{$payload->{"commits"}} ) {
    my $longsha = $commit->{"id"};
    my $shortsha = substr $longsha, 0, 7;
    my $changeurl = $commit->{"url"};
    $changeurl =~ s/$longsha$/$shortsha/;

    my $subject = "$repository commit: $shortsha by " .
                  "$commit->{"author"}->{"name"} (";
    if ($commit->{"author"}->{"username"}) {
        $subject .= $commit->{"author"}->{"username"};
    } else {
        $subject .= "no github username";
    }
    $subject .= ")";

    my $email = <<EOF;
      Author:  $commit->{"author"}->{"name"} <$commit->{"author"}->{"email"}>
 Change Date:  $commit->{"timestamp"}
   Push Date:  $payload->{"repository"}->{"pushed_at"}
  Repository:  $repository
      Branch:  $branch
New Revision:  $commit->{"id"}
   Changeset:  $changeurl

Log:

$commit->{"message"}

EOF

    my @array = @{$commit->{"added"}};
    if ($#array != -1) {
        $email .= "Added:\n\n   " . join("\n   ", @array) . "\n\n";
    }

    @array = @{$commit->{"removed"}};
    if ($#array != -1) {
        $email .= "Removed:\n\n   " . join("\n   ", @array) . "\n\n";
    }

    @array = @{$commit->{"modified"}};
    if ($#array != -1) {
        $email .= "Modified:\n\n   " . join("\n   ", @array) . "\n\n";
    }

    # Send the email
    my $msg = Mail::Send->new;
    $msg->subject($subject);
    foreach my $h (keys %headers) {
        $msg->set($h, $headers{$h});
    }

    my $fh = $msg->open;
    print $fh $email;
    $fh->close;
}

