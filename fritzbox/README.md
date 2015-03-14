# wgplugin/fritzbox

You need to enable TCP connection on your Fritzbox and create a socat-entry like that:

    socket 1: tcp-connect     <IP-Fritzbox>:1012       cr,forever
    socket 2: udp-datagram    localhost:50150          bind=localhost:50151,reuseaddr
d

* callmonitor.pl - This the WG plugin. It will write all calls to your sqlite database
* calllist.php - This needs to be accessible for your webserver and can be integrated in your visu. The styling information is included in the file. 

