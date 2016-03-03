# PingCheck v1.0
# 
# Copyright 2016: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#
# COMPILE_PLUGIN 
 
#
# config starts here
#

my @hosts = (
  { 'host' => '192.168.0.1',  # ip or domain name of host
    'proto' => 'icmp',  # optional protocol: tcp, udp, icmp (default set below)
    'timeout' => 2, # optional timeout in seconds (default set below)
    'ga' => '11/11/11' }, # status ga
  { 'host' => 'unifiap', 'ga' => '11/11/13' },
  { 'host' => 'unifiap2', 'ga' => '11/11/14' },
  { 'host' => 'visupc', 'ga' => '11/11/15' },
  { 'host' => 'dectgw', 'ga' => '11/11/16' },
  { 'host' => 'smarthome', 'ga' => '11/11/12' },
  );

my $default_timeout = 1; # default timeout for response, REQUIRED
my $default_proto = 'icmp'; # default protocol for ping, REQUIRED

my $check_cycle = 300; # set interval in seconds
my $debug = 0; # print debug messages

#
# config ends here
#

use Net::Ping;

$plugin_info{$plugname.'_cycle'} = $check_cycle; 

foreach (@hosts) {  
  my $proto = $_->{'proto'} // $default_proto;
  my $timeout = $_->{'timeout'} // $default_timeout;

  my $ping = Net::Ping->new($proto, $timeout);

  my $status = $ping->ping($_->{'host'});
  knx_write($_->{'ga'}, $status)   if (exists $_->{'ga'});
  plugin_log($plugname, "$_->{'host'} is ".($status ? 'alive' : 'dead')." (using $proto) ") if $debug;

}

return;