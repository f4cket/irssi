## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load notify
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
use HTML::Entities;
use DBI;
use utf8;

$VERSION = "0.01";
%IRSSI = (
    authors     => 'Allan Willems Joergensen',
    origauthors => 'Luke Macken, Paul W. Frields, Jared Quinn',
    contact     => 'allan@nowhere,dk',
    name        => 'notifier.pl',
    description => 'Use libnotify to alert the user of new messages or hilights (Using MySQL as "proxy")',
    license     => 'GNU General Public License',
    url         => 'http://www.nowhere.dk/articles/irssi-notification',
);

Irssi::settings_add_str('notifier','notifier_mysql_user', 'changeme');
Irssi::settings_add_str('notifier','notifier_mysql_password', 'changeme');
Irssi::settings_add_str('notifier','notifier_mysql_host', 'changeme');
Irssi::settings_add_str('notifier','notifier_mysql_db', 'changeme');

sub write2db {
        my $db_user = Irssi::settings_get_str('notifier_mysql_user');
        my $db_pass = Irssi::settings_get_str('notifier_mysql_password');
        my $db_host= Irssi::settings_get_str('notifier_mysql_host');
        my $db_name = Irssi::settings_get_str('notifier_mysql_db');
        my ($summary, $message) = @_;
        my $dsn = "dbi:mysql:dbname=$db_name;host=$db_host";
        my $dbh = DBI->connect($dsn, $db_user, $db_pass) || die "DB connect failed";

        my $sth = $dbh->prepare("INSERT INTO notify (summary, message) VALUES (?, ?)")
            or die "Can't prepare statement: $?";
        $sth->execute($summary, $message) or die "Couldn't execute INSERT: $?";

        $dbh->disconnect;
}


sub notify {
    my ($server, $summary, $message) = @_;
    my $safemsg = HTML::Entities::encode($message, '<>&"');
    my $utf8msg = utf8::encode($safemsg);

    write2db($summary, $safemsg);
}

sub print_text_notify {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};
    return if (!$server || !($dest->{level} & MSGLEVEL_HILIGHT));
    my $sender = $stripped;
    $sender =~ s/^\<.([^\>]+)\>.+/\1/ ;
    $stripped =~ s/^\<.[^\>]+\>.// ;
    my $summary = "Hilite in " . $dest->{target};
    notify($server, $summary, $stripped);
}


sub message_private_notify {
    my ($server, $msg, $nick, $address) = @_;
    return if (!$server);
    notify($server, "Private message from ".$nick, $msg);
}

sub dcc_request_notify {
    my ($dcc, $sendaddr) = @_;
    my $server = $dcc->{server};

    return if (!$dcc);
    notify($server, "DCC ".$dcc->{type}." request", $dcc->{nick});
}

Irssi::signal_add('print text', 'print_text_notify');
Irssi::signal_add('message private', 'message_private_notify');
Irssi::signal_add('dcc request', 'dcc_request_notify');
