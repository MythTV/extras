#! /usr/bin/perl
# vim:ts=4:sw=4:ai:et:si:sts=4

use strict;
use warnings;
use Apache2::Const -compile => qw(M_POST HTTP_METHOD_NOT_ALLOWED);
use CGI;
use JSON;
use Mail::Send;
use Config::General;
use DBI;
use File::Basename;
use English;
use Cwd 'abs_path';

my $filtered = 0;
my $r = shift;

unless ($r->method_number == Apache2::Const::M_POST) {
    $r->allowed($r->allowed | (1 << Apache2::Const::M_POST));
    $r->status(Apache2::Const::HTTP_METHOD_NOT_ALLOWED);
    return;
}

my $conffile = dirname(abs_path($0 or $PROGRAM_NAME)) . "/email_hook.cfg";
my $conf = new Config::General($conffile);
my %config = $conf->getall;

my $debug = $config{'debug'} or 0;

$r->content_type('text/html');
$r->print();


# Payload is described at http://help.github.com/post-receive-hooks/
my $json    = JSON->new->utf8;
my $payload = CGI->new->param('payload');

# Log the raw payload too!
if ( $debug ) {
    open FH, ">>", "/tmp/dump.raw..json";
    print FH "$payload\n";
    close FH;
}

$payload    = $json->decode($payload);

if ( $debug ) {
    open FH, ">>", "/tmp/dump.json";
    print FH $json->pretty->encode($payload);
    close FH;
}

my $repository = $payload->{"repository"}->{"name"};
my $branch = $payload->{"ref"};
$branch =~ s/^refs\/.*?\///;

my $regexp = qr($config{'ignoreregexp'});
if ($branch !~ $regexp) {
    $filtered = 1;
}

my $dbh = DBI->connect("dbi:mysql:database=".$config{'db'}{'database'}.
                       ":host=".$config{'db'}{'host'},
                       $config{'db'}{'user'}, $config{'db'}{'password'})
            or die "Cannot connect to database: " . DBI::errstr . "\n";

my $q = "SELECT sha1 FROM seen WHERE repo = ? AND sha1 = ?";
my $select_h = $dbh->prepare($q);

$q = "INSERT INTO seen (repo, sha1, lastseen) VALUES (?, ?, NULL)";
my $insert_h = $dbh->prepare($q);


# These maybe should go into a config file later
my %commitsheaders = (
    "From"          => 'MythTV <noreply@mythtv.org>',
    "To"            => 'mythtv-commits@mythtv.org',
    "Reply-to"      => 'mythtv-dev@mythtv.org',
    "X-Repository"  => $repository,
    "X-Branch"      => $branch,
);

my %firehoseheaders = (
    "From"          => 'MythTV <noreply@mythtv.org>',
    "To"            => 'mythtv-firehose@mythtv.org',
    "Reply-to"      => 'mythtv-dev@mythtv.org',
    "X-Repository"  => $repository,
    "X-Branch"      => $branch,
);

foreach my $commit ( @{$payload->{"commits"}} ) {
    my $longsha = $commit->{"id"};
    $select_h->execute($repository,$longsha);
    next if $select_h->rows;

    my $shortsha = substr $longsha, 0, 9;
    my $changeurl = $commit->{"url"};
    $changeurl =~ s/$longsha$/$shortsha/;

    my $subject = "$repository/$branch commit: $shortsha by " .
                  $commit->{"author"}->{"name"} . " (";
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

    # Send the firehose email
    send_email($subject, $email, \%firehoseheaders);

    # Send the commits email
    send_email($subject, $email, \%commitsheaders) if !$filtered;

    $insert_h->execute($repository,$longsha);
}

sub send_email {
    my ($subject, $email, $headers) = @_;

    my $msg = Mail::Send->new;
    $msg->subject($subject);
    foreach my $h (keys %{$headers}) {
        $msg->set($h, $headers->{$h});
    }

    my $fh = $msg->open;
    print $fh $email;
    $fh->close;
}
