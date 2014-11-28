# MySQLStoreEvent v1.0
# 
# Copyright 2014: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#

# please install libdbd-mysql-perl package

# database-structure: (must be present prior to use of this plugin)
#
# field 	type		standard_value		extra
# id		int(11)					auto_increment
# timestamp	timestamp	current_timestamp
# name		varchar(255)
# value		decimal(18,9)
#
# type of column value can be adjusted according to stored data (double, int, ..)
#
# config starts here
#

my $db_host = '192.168.0.52'; # access data for MySQL-database 
my $db_name = 'wgdata';
my $db_user = 'wguser';
my $db_password = 'wgtest';
my $db_table = 'tabelle2';

# enter groupadress and item name
my %config = ( '5/0/130' => 'bad_fenster', '5/0/140' => 'kueche_fenster');

my $debug = 1; # 0 if no debug, 1 if debug

#
# config ends here
#
# do not change anything below
#

use DBI; 

if ($msg{'apci'} eq "A_GroupValue_Write") { # received telegram
  plugin_log($plugname, "received $msg{'value'} for $msg{'dst'}") if $debug;
  
  my $item = $config{$msg{'dst'}};
  my $value = $msg{'value'};
  
  my $sql_query = "INSERT INTO $db_table (name, value) VALUES ('$item', $value)"; 
  plugin_log($plugname, "SQL: $sql_query") if $debug;  
  
  my $db_handle = DBI->connect("DBI:mysql:$db_name;host=$db_host", $db_user, 
    $db_password, { RaiseError => 1 } );
  $db_handle->do($sql_query);
  $db_handle->disconnect();
} else { # init call
  
  $plugin_info{$plugname.'_cycle'} = 0; # we only go on telegrams
  foreach my $key (keys %config) {
    $plugin_subscribe_write{$key}{$plugname} = 1;
    plugin_log($plugname, "subcribing to $key") if $debug;
  } 
}

return;
