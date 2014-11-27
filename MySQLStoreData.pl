# MySQLStoreData v1.0
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
# wert1		double
# wert2		double
# ...

#
# config starts here
#

$plugin_info{$plugname.'_cycle'} = 150; # set interval in seconds

my $db_host = '192.168.0.52'; # access data for MySQL-database 
my $db_name = 'wgdata';
my $db_user = 'wguser';
my $db_password = 'wgtest';
my $db_table = 'tabelle1';

# enter fieldname and group address for each value
my %config = ( 'vorlauf' => '5/2/10', 'ruecklauf' => '5/2/11', 
  'kessel' => '5/2/12' );

my $debug = 0; # 0 if no debug, 1 if debug

#
# config ends here
#
# do not change anything below
#

use DBI; 

my $fieldlist = "";
my $valuelist = "";

foreach my $key (keys %config) {
 $fieldlist .= ",$key";
 $valuelist .= ",".knx_read($config{$key});
} 

$fieldlist =~ s/^.//s;
$valuelist =~ s/^.//s;

my $sql_query = "INSERT INTO $db_table ($fieldlist) VALUES ($valuelist)";

plugin_log($plugname, $sql_query) if $debug;

my $db_handle = DBI->connect("DBI:mysql:$db_name;host=$db_host", $db_user, 
  $db_password, { RaiseError => 1 } );
$db_handle->do($sql_query);
$db_handle->disconnect();

return;
