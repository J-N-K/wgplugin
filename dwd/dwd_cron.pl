#!/usr/bin/perl -w
#
# dwd_cron.pl v1.0
#
# Copyright 2015: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#

use strict;

use Net::FTP;
use IO::Socket;
use DateTime;

# DWD
my $user = "gds#####";
my $password = "######";
my $region = "EM";
my $location = "GEXX";

# HTML Output
my $html_file = "/var/www/dwd_warning.html";
my $html_ww_icon = "/cometvisu/icon/knx-uf-iconset/128x128_white/message_notice.png";
my $html_wpu_icon = "/cometvisu/icon/knx-uf-iconset/128x128_white/message_attention_2.png";
my $html_dateformat = "%a, %d.%m., %H:%M";
my $html_stylesheet = "/dwd_warnings.css";

# UDP warnings
my $udp_port = 60000;
my $udp_host = 'localhost';

# Sonstiges
my $tz = "Europe/Berlin";
my $locale = "de_DE";
my $process_all = 0;
my $debug = 0;

#
# Code
#
my %wpucodes = (40 => 'schweres Gewitter mit orkanartigen Böen oder Orkanböen',41 => 'schweres Gewitter mit extremen Orkanböen',
  42 => 'schweres Gewitter mit schweren Sturmböen und heftigem Starkregen',44 => 'schweres Gewitter mit orkanartigen Böen oder Orkanböen und heftigem Starkregen',
  45 => 'schweres Gewitter mit extremen Orkanböen und heftigem Starkregen',46 => 'schweres Gewitter mit schweren Sturmböen, heftigem Starkregen und Hagel',
  48 => 'schweres Gewitter mit orkanartigen Böen oder Orkanböen, heftigem Starkregen und Hagel',49 => 'schweres Gewitter mit extremen Orkanböen, heftigem Starkregen und Hagel',
  54 => 'orkanartige Böen',55 => 'Orkanböen',56 => 'Orkanböen ab 140 km/h',62 => 'heftiger Starkregen',64 => 'ergiebiger Dauerregen',65 => 'ergiebiger Dauerregen ',
  66 => 'extrem heftiger Starkregen',72 => 'starker Schneefall',73 => 'starker Schneefall ',75 => 'starke Schneeverwehung',77 => 'starker Schneefall und Schneeverwehung ',
  78 => 'extrem starker Schneefall und Schneeverwehung ',85 => 'Glatteis',89 => 'starkes Tauwetter',94 => 'schweres Gewitter mit Sturmböen und heftigem Starkregen ',
  95 => 'schweres Gewitter mit Sturmböen, extrem heftigem Starkregen und Hagel',96 => 'schweres Gewitter mit Orkanböen, extrem heftigem Starkregen und Hagel');
my %wwcodes = (21 => 'Frost in Bodennähe',22 => 'Frost',24 => 'Glätte',31 => 'Gewitter',33 => 'starkes Gewitter mit Sturmböen',34 => 'starkes Gewitter mit Starkregen',
  36 => 'starkes Gewitter mit Sturmböen und Starkregen',38 => 'starkes Gewitter mit Sturmböen, Starkregen und Hagel',45 => 'Hoher UV-Index',46 => 'Hoher UV-Index',
  47 => 'Hitzewarnung',48 => 'Hitzewarnung',49 => 'Hitzewarnung',50 => 'Starkwind',51 => 'Windböen',52 => 'Sturmböen',53 => 'schwere Sturmböen',57 => 'Starkwindwarnung',
  58 => 'Sturmwarnung',59 => 'Nebel',61 => 'Starkregen',63 => 'Dauerregen',70 => 'leichter Schneefall',71 => 'Schneefall',74 => 'Schneeverwehung',
  76 => 'Schneefall und Schneeverwehung',81 => 'Frost',82 => 'strenger Frost',84 => 'Glätte',87 => 'Glätte',88 => 'Tauwetter');

# first get DWD file

my $ftp = Net::FTP->new("ftp-outgoing2.dwd.de", Debug => 0)
  or die("Could not open FTP connection: $@");

$ftp->login($user, $password)
  or die("Could not login; $@");


my @files = $ftp->ls("gds/specials/warnings/$region/W*_$location*")
  or die("Could not get directory: $@");

my $warnings = '';

open(my $FILE, ">$html_file");

print $FILE "<html><head> <meta http-equiv=\"Content-Type\" content=\"text/html;charset=ISO-8859-1\"> <link rel=\"stylesheet\" type=\"text/css\" href=\"$html_stylesheet\"> </head>\n";
print $FILE "<body><div class=\"dwd_caption\">DWD-Unwetterwarnungen</div><table>\n";

my $warning_num = 0;

foreach (@files) {
  print "Retrieving $_ \n" if $debug;
  my $xfr_handle = $ftp->retr($_);
  if ($xfr_handle) {
    my @this_warning;
    my @this_dates;
    my $this_line;
    while(<$xfr_handle>) {
      my $line = $_;
      $line =~ s/^\s+|\s+$//g;
      if ($line) {
        $this_line .= $line." ";
        if ($line =~ /(\d\d\.\d\d\.\d\d\d\d \d\d:\d\d)/) {
          push(@this_dates, $1);
        }
      } else {
        push(@this_warning, $this_line."\n");
        $this_line = '';
      }
    }
    $xfr_handle->abort();
    if (scalar(@this_dates)>1) {
      $this_dates[0] =~ /(\d*)\.(\d*)\.(\d*) (\d*):(\d*)/;
      my $start = DateTime->new(year => $3, month => $2, day => $1, hour => $4, minute => $5, time_zone => $tz, locale => $locale);

      $this_dates[1] =~ /(\d*)\.(\d*)\.(\d*) (\d*):(\d*)/;
      my $end = DateTime->new(year => $3, month => $2, day => $1, hour => $4, minute => $5, time_zone => $tz, locale => $locale);

      my $now= DateTime->now(time_zone => $tz);

      print "Start: $start, End: $end, Now: $now \n" if $debug;

      if (($now > $end) && !$process_all) { # already passed
        print "Skipping past event\n" if $debug;
      } else {
	$warning_num++;
        $this_warning[0] =~ /(\w\w)\Q$region\E(\d\d)\s/;
        my $type = $1;
        my $code = $2;
	if (($now > $start) && ($end > $now)) { #UDP only current
          $warnings .= "$1:$2 ";
	}
	my $text = ($type eq "WW") ? $wwcodes{$code} : $wpucodes{$code};
	my $icon = ($type eq "WW") ? $html_ww_icon : $html_wpu_icon;
	my $starttext = $start->strftime($html_dateformat);
	my $endtext = $end->strftime($html_dateformat);
        print $FILE "<tr class=\"dwd_type_$type dwd_code_$code\"><td><img src=\"$icon\" /></td><td>$starttext - $endtext</td><td>$text</td></tr></td>\n";      
      }
    }
  } else {
    print "Could not retrieve previously listed file $_\n" if $debug;
  }
}
print $FILE "</table>\n";

if (!$warning_num) {
  print $FILE "<div class=\"dwd_nowarning\">keine</dwd>";
}

print $FILE "</body></html>\n";

$ftp->quit();
close($FILE);

print "All warning UDP: $warnings \n" if $debug;
my $sock = IO::Socket::INET->new(Proto => 'udp', PeerPort => $udp_port, PeerAddr =>  $udp_host)
  or die('Could not open Socket');

$sock->send("$warnings\n") 
  or die('Could not send data');

$sock->close();
