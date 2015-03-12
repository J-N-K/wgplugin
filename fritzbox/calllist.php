<!-- Fritzbox Callmonitor v2.0
     Copyright 2015: JNK (http://knx-user-forum.de/members/jnk.html)
     latest version available on https://github.com/J-N-K/wgplugin
-->

<?php

// look where to store DB
$dbfile = '/var/local/callmonitor.db';
$iconpath = '/cometvisu/icon/knx-uf-iconset/128x128_white/';
$fax = '020xxxxxxx'; # number of fax machibe

//check if the database is readable by the webserver
$dbfile_dir = dirname($dbfile);
if (! is_readable($dbfile_dir))
    die ("Database $dbfile not readable! make sure the file AND " .
        "the directory are readable by the webserver!");

// create database connection
$db = sqlite_open($dbfile, 0666, $error);
if (!$db) die ($error);

$sql="SELECT * FROM calldata WHERE NOT (what='no_response') ORDER BY id DESC LIMIT 5";
$result = sqlite_query($db, $sql, SQLITE_ASSOC);

?>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
    <style type="text/css">
      @font-face {
        font-family: "Dosis";
        font-style: normal;
        font-weight: 400;
        src: url("/cometvisu/fonts/Dosis-Medium.ttf");
      }

      body {
        //background: #000;
        color: #fff;
        font-family: Dosis,Helvetica,Arial,sans-serif;
        font-size: 4mm;
        margin: 0;
        overflow: hidden;
        text-shadow: 0 1px 1px #111;
      }

      img {
        height: 2em;
      }

      div {
        line-height: 1em;
        padding: 0.3em 0.3em 0.3em 1em;
      }
      td {
        padding: 0.3em 0.3em 0.3em 1em;
        line-height: 1em;
      }

      td + td {
        padding-left: 1.5em;
      }

    </style>
  </head>
  <body>
  <table>
  <?php
  while( sqlite_has_more($result) )
  { // local, remote, direction, what, date
    $row = sqlite_fetch_array($result, SQLITE_ASSOC );
    if (strcmp($row['what'], 'no_response')) {
      echo '<tr>';
      if (!strcmp($row['local'], $fax)) {
        echo '<td><img src="' . $iconpath . 'it_fax.png" /></td>';
      } elseif (!strcmp($row['what'], 'responder')) {
        echo '<td><img src="' . $iconpath . 'phone_answersing.png" /></td>';
      } else {
        echo '<td />';
      }
      if (!strcmp($row['what'], 'missed')) {
        echo '<td><img src="' . $iconpath . 'phone_missed_in.png" /></td>';
      } elseif (!strcmp($row['direction'], 'inbound')) {
        echo '<td><img src="' . $iconpath . 'phone_call_in.png" /></td>';
      } else {
        echo '<td><img src="' . $iconpath . 'phone_call_out.png" /></td>';
      }
      echo '<td>' . $row['date'] . '</td>';
      echo '<td>' . preg_replace('/[^0-9]/', '', $row['remote']) . '</td>';
      echo "</tr>\n";
    }
  }
  ?>
</table>
</body></html>
<?php
sqlite_close($db);
?>

