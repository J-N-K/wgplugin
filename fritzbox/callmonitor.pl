# Fritzbox Callmonitor v2.0
#
# Copyright 2012-15: JNK (http://knx-user-forum.de/members/jnk.html)
# latest version available on https://github.com/J-N-K/wgplugin
#

#
# config starts here
#

my $socknum = 29; # unique socket number

my $send_ip = "localhost";
my $send_port = "50151"; 
my $recv_ip = "localhost";
my $recv_port = "50150";

# socket parameters:
# socket 1: tcp-connect     <IP-Fritzbox>:1012       cr,forever
# socket 2: udp-datagram    localhost:50150          bind=localhost:50151,reuseaddr

my %localnumbers =10 (
  "0209XXXXXXX" => "Janessa Fon",
  "0209XXXXXXX" => "Janessa Fax"
);

my %remotenumbers = (
  "0157XXXXXXX" => { name => "Jan", 
    ring => { GA => "7/0/1", DPT => 1, value => 1 },
    missed => { GA => "7/1/1", DPT => 1, value => 1 }
  },
  "0176XXXXXXX" => { name => "Essa", 
    ring => { GA => "7/0/2", DPT => 1, value => 1 }
  }
);
  
# path to call database
my $logdb = '/var/local/callmonitor.db';

my $debug = 0; # 0 = no debug, 1 = debug

#
# config ends here
#
# do not change anything below
#

use DBI;
use DateTime;

if ($logdb ne "") { # check if logdb is defined
  # check setup, rights, DB
  if (! -d dirname($logdb)) {
    mkdir(dirname($logdb),0777);
  }
  if (! -e $logdb) {
    my $sql = "CREATE TABLE calldata (id INTEGER PRIMARY KEY, " 
      ." local VARCHAR(20), remote VARCHAR(20), direction VARCHAR(20), "
      ." what VARCHAR(20), date VARCHAR(20) );";
    my $dbargs = {AutoCommit => 0, PrintError => 1};
    my $dbh = DBI->connect("dbi:SQLite2:dbname=$logdb", "", "", $dbargs);
    plugin_log($plugname, "DB-Error: $DBI::errstr") if $dbh->err();
    $dbh->do($sql);
    plugin_log($plugname, "DB-Error: $DBI::errstr") if $dbh->err(); 
    $dbh->commit();
    $dbh->disconnect();
   
    plugin_log($plugname, "created new database $logdb");
  }
}

$plugin_info{$plugname.'_cycle'} = 0; # call on telegram only

if (!$socket[$socknum]) { # create socket
        $socket[$socknum] = IO::Socket::INET->new(LocalPort => $recv_port,
                                  Proto => "udp",
                                  LocalAddr => $recv_ip,
                                  PeerPort  => $send_port,
                                  PeerAddr  => $send_ip,
                                  ReuseAddr => 1
                                   )
    or return ("open of $recv_ip : $recv_port failed: $!");

    $socksel->add($socket[$socknum]); # add socket to select

    $plugin_socket_subscribe{$socket[$socknum]} = $plugname; # subscribe plugin
    plugin_log($plugname, "opened Socket $socknum");
    return "Init";
} elsif ($fh) { 
    my $line;
    $fh->recv($line, 1024);
    chomp($line);

    if (!$line) { # catch empty line
      return;
    }
    
    if ($debug>1) { # for debug : printout received string as hex and ascii
      my $str = unpack('H*', "$line");
      plugin_log($plugname, $str);
      plugin_log($plugname, $line);
    }
    
    my @elem = split(/;/, $line); # separator is ;

    (my $day, my $month, my $year, my $hour, my $minute) = split(/[. :]/, $elem[0]);
    $year = "20" . $year;
  
    my $calldate =  DateTime->new( year => $year, month => $month, day => $day,
      hour => $hour, minute => $minute, second =>0, time_zone => 'Europe/Berlin');

    $calldate->set_time_zone('UTC'); # all sqlite-data is in UTC !

    my $date = $calldate->strftime("%Y-%m-%d %T");
    my $action = $elem[1];
    my $CID = $elem[2];
    
    given( $action ) {
      when( 'CALL' ) { # outbound call
        my $remotenr = $elem[5];      
        my $localnr = $elem[4];
        my ($remote, $local);
        if (exists $localnumbers{$localnr}) {  #lookup local number
          $local = $localnumbers{$localnr}; 
        } else {
          $local = $localnr; 
        }
        if (exists $remotenumbers{$remotenr}) { #lookup  remote number
          $remote = $remotenumbers{$remotenr}{"name"};
        } else {
          $remote = $remotenr;
        }
        if ($debug>0) { 
          plugin_log($plugname, "outbound from $local to $remote" ); 
        }
        $plugin_info{$plugname."_CID".$CID."inbound"} = 0; #store call data
        $plugin_info{$plugname."_CID".$CID."local"} = $local;
        $plugin_info{$plugname."_CID".$CID."remote"} = $remotenr;
        $plugin_info{$plugname."_CID".$CID."date"} = $date;
        $plugin_info{$plugname."_CID".$CID."state"} = 'pending';
      };
      when( 'RING' ){ # inbound call
        my $remotenr = $elem[3];      
        my $localnr = $elem[4];
        my ($remote, $local); 
        if (exists $localnumbers{$localnr}) { #lookup local number
          $local = $localnumbers{$localnr}; 
        } else {
          $local = $localnr; 
        }
        if (exists $remotenumbers{$remotenr}) { # lookup remote number
          $remote = $remotenumbers{$remotenr}{"name"};
          if (exists $remotenumbers{$remotenr}{"ring"}) { # ring action defined?
            knx_write($remotenumbers{$remotenr}{"ring"}{"GA"}, 
              $remotenumbers{$remotenr}{"ring"}{"value"}, 
              $remotenumbers{$remotenr}{"ring"}{"DPT"});
          }
        } else {
          $remote = $remotenr;
        }
        $plugin_info{$plugname."_CID".$CID."inbound"} = 1; #store data
        $plugin_info{$plugname."_CID".$CID."local"} = $local;
        $plugin_info{$plugname."_CID".$CID."remote"} = $remotenr;
        $plugin_info{$plugname."_CID".$CID."date"} = $date;
        $plugin_info{$plugname."_CID".$CID."state"} = 'pending';
        $plugin_info{$plugname."_CID".$CID."ext"} = '';
        if ($debug>0) { 
          plugin_log($plugname, "$CID : inbound to $local from $remote" ); 
        }        
      };
      when( 'CONNECT' ){ # switch state to connected
        if ($debug>0) {
          plugin_log($plugname, "$CID : connected" );
        }
        $plugin_info{$plugname."_CID".$CID."state"} = 'connect';
        $plugin_info{$plugname."_CID".$CID."ext"} = $elem[3];
        
      };
      when( 'DISCONNECT' ){ #check disconnect
        my $what;
        my $remotenr = $plugin_info{$plugname."_CID".$CID."remote"};        
        if ($plugin_info{$plugname."_CID".$CID."state"} eq 'connect') { # call was successfull
          if ($plugin_info{$plugname."_CID".$CID."ext"} >= 40) {
            $what = "responder";
          } else { 
            $what = "hangup";
          }
          # tba
        } else { # either missed or no response
          plugin_log($plugname, "missed");
          if ($plugin_info{$plugname."_CID".$CID."inbound"} == 1) { # missed
            $what = "missed";
            if (exists $remotenumbers{$remotenr}{"missed"}) { # missed action defined?
              knx_write($remotenumbers{$remotenr}{"missed"}{"GA"}, 
              $remotenumbers{$remotenr}{"missed"}{"value"}, 
              $remotenumbers{$remotenr}{"missed"}{"DPT"});
            } 
          } else {
            $what = "no_response";
          }   
        }
        my $remote = (exists $remotenumbers{$remotenr}{"missed"}) ?
         $remotenumbers{$remotenr}{"name"} : $remotenr;
        my $local = $plugin_info{$plugname."_CID".$CID."local"};
        my $date = $plugin_info{$plugname."_CID".$CID."date"};
        my $direction = ($plugin_info{$plugname."_CID".$CID."inbound"}==1) ? 
          "inbound" : "outbound";
        if ($logdb ne "") { # only try to insert if defined
          my $sql = "INSERT INTO calldata(local, remote, direction, what, date) VALUES( " .
            " '$local', '$remote', '$direction', '$what', '$date' );";
          my $dbargs = {AutoCommit => 0, PrintError => 1};
          my $dbh = DBI->connect("dbi:SQLite2:dbname=$logdb", "", "", $dbargs);
          $dbh->do($sql);
          if ($dbh->err()) { 
            plugin_log($plugname, "DB-Fehler: $DBI::errstr"); 
          }
          $dbh->commit();
          $dbh->disconnect();
        }

        $plugin_info{$plugname."_CID".$CID."state"} = $what;
        if ($debug>0) {
          plugin_log($plugname, "$CID : disconnected ($what)" );
        }
      };
    }
}

return;
