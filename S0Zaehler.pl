# S0 Zaehler v1.2
# 
# Copyright 2016: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#
# COMPILE_PLUGIN

#
# config starts here
#

my $counters = {
  '5/4/100' => { # GA of S0 counter 
     'name' => 'gas', # arbitrary unique name, used for RRD
     'value_ga' => '5/4/0', # total value counter GA
     'usage_ga' => '5/4/10', # current usage GA
     'offset' => 2434891, # offset of S0 counts / meter reading
     's0scaling' => 100, # scaling factor S0 counts / counter units
     },
  '5/4/101' => { 
     'name' => 'strom',
     'value_ga' => '5/4/1',
     'usage_ga' => '5/4/11',
     'offset' => 68737500,
     's0scaling' => 1000,
     'usagescaling' => 3600000, # (kWh => Ws) 
     }, 
  };

my $rrdpath = "/var/www/rrd";		# path to RRD files
my @countermodes = (5,15,60,1440);	# resolution for COUNTER RRDs in minutes (1440 = daily usage)

my $debug = 1; # print debug messages

#
# config ends here
#

my $now = time();

if (($msg{'apci'} eq "A_GroupValue_Write") && (exists $counters->{$msg{'dst'}})) {
  my $counter = $counters->{$msg{'dst'}};
  my $name = $counter->{'name'};
  
  # calculate counter value
  my $s0_cts = $msg{'value'};
  my $total = $counter->{'offset'} + $s0_cts;  
  
  # store in RRD
  foreach (@countermodes) {
    my $rrdname = $name."_".$_."\.rrd";
    my $rrdfile = $rrdpath."\/".$rrdname;
    unless (-e $rrdfile) {
      RRDs::create ($rrdfile,"DS:value:COUNTER:".(($_*60)+600).":0:10000000000","RRA:AVERAGE:0.5:1:365","RRA:AVERAGE:0.5:7:300","-s ".($_*60));
    }
    my $storevalue = int($total*$_*60);
    RRDs::update("$rrdfile", "N:$storevalue");
  }
 
  # write to knx
  my $ctr_value = $total/$counter->{'s0scaling'}; 
  knx_write($counter->{'value_ga'}, $ctr_value) if ($counter->{'value_ga'});
  
  my $scaling = ($counter->{'usagescaling'} // 1) / $counter->{'s0scaling'};
  my $usage = ($total - $plugin_info{$plugname.'_'.$name.'_value'}) / ($now - $plugin_info{$plugname.'_'.$name.'_last'}) * $scaling;
  knx_write($counter->{'usage_ga'}, $usage) if ($counter->{'usage_ga'});
    
  # save last value and timestamp
  $plugin_info{$plugname.'_'.$name.'_value'} = $total;
  $plugin_info{$plugname.'_'.$name.'_last'} = $now;
    
  plugin_log($plugname, "Counter $name: Counts=$s0_cts, Total=$total, Value=$ctr_value, Usage=$usage") if $debug;
} else {
  foreach my $sub_ga (keys %$counters) {
    my $name = $counters->{$sub_ga}{'name'};
    
    plugin_log($plugname, "Subscribing to $sub_ga ($name)") if $debug;
    $plugin_subscribe{$sub_ga}{$plugname} = 1;  

    if (!exists $plugin_info{$plugname."_".$name."_value"}) {
      $plugin_info{$plugname."_".$name."_value"} = $counters->{$sub_ga}{'offset'};
    }
    if (!exists $plugin_info{$plugname."_".$name."_last"}) {
      $plugin_info{$plugname."_".$name."_last"} = $now;
    }  
  }
  
  $plugin_info{$plugname.'_cycle'} = 0; # nur bei GA aufrufen
}

return;
