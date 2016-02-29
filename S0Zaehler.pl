# S0 Zaehler v1.0
# 
# Copyright 2016: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#

#
# config starts here
#

my $s0_ga = '5/4/101'; # GA auf der die S0-Impulse ankommen
my $zaehler_ga = '5/4/1'; # GA auf den der Gesamtzaehlerstand gesendet wird
my $verbrauch_ga = '5/4/11'; # GA auf den der aktuelle Verbrauch gesendet wird

my $ctr_offset = 68737500; # Offset des Zaehlers gegenueber den S0 Impulsen
my $s0_scaler = 1000; # Faktor Impulse/Einheit 

my $rrdpath = "/var/www/rrd";		#Pfad fuer RRDs
my @countermodes = (5,15,60,1440);	#Aufloesungen fuer COUNTER RRDs in Minuten (1440 = Tagesverbrauch)

my $debug = 0; # Debug-Meldungen ausgeben?

#
# config ends here
#

if (($msg{'apci'} eq "A_GroupValue_Write") && ($msg{'dst'} eq $s0_ga)) {
  # calculate counter value
  my $s0_cts = $msg{'value'};
  my $ctr_total = $ctr_offset + $s0_cts;  
  my $now = time();
  
  # store in RRD
  foreach (@countermodes) {
    my $counterid = "strom";
    my $rrdname = $counterid."_".$_."\.rrd";
    my $rrdfile = $rrdpath."\/".$rrdname;
    unless (-e $rrdfile) {
      RRDs::create ($rrdfile,"DS:value:COUNTER:".(($_*60)+600).":0:10000000000","RRA:AVERAGE:0.5:1:365","RRA:AVERAGE:0.5:7:300","-s ".($_*60));
    }
    my $storevalue = int($ctr_total*$_*60);
    RRDs::update("$rrdfile", "N:$storevalue");
  }
 
  # write to knx
  my $ctr_value = $ctr_total/$s0_scaler; 
  if ($zaehler_ga) {
    knx_write($zaehler_ga, $ctr_value);
  }
  
  my $verbrauch = ($ctr_total - $plugin_info{$plugname.'_value'})/($now - $plugin_info{$plugname.'_valuelast'});
  if ($verbrauch_ga) {
    knx_write($verbrauch_ga, $verbrauch);
  }
    
  # save last value and timestamp
  $plugin_info{$plugname.'_value'} = $ctr_total;
  $plugin_info{$plugname.'_valuelast'} = $now;
    
  plugin_log($plugname, "Counts=$s0_cts, Gesamt=$ctr_value, Verbrauch=$verbrauch") if $debug;
} else {
  $plugin_subscribe{$s0_ga}{$plugname} = 1;
  $plugin_info{$plugname.'_cycle'} = 0;
}

return;
