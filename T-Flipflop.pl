# T-FlipFlop v1.0
#
# Copyright: JNK (http://knx-user-forum.de/members/jnk.html)
#

my $in_ga = "9/0/0";   # Eingangs-GA
my $out_ga =  "9/0/1"; # Ausgangs-GA



if (($msg{'apci'} eq "A_GroupValue_Write") && ($msg{'dst'} eq $in_ga)) {
  if ($msg{'value'} == 0) { # Status ist 0, nur merken
      $plugin_info{$plugname.'_last_state'} = 0;
  } else { # Status ist 1
    if ($plugin_info{$plugname.'_last_state'} == 0) { # Status geaendert
      $plugin_info{$plugname.'_last_state'} = 1; # Status merken
      $plugin_info{$plugname.'_last_flipflop_state'} = !$plugin_info{$plugname.'_last_flipflop_state'};
      knx_write($out_ga, $plugin_info{$plugname.'_last_flipflop_state'});
    }
  }
} else { # first call
  if (not exists $plugin_info{$plugname.'_last_group_state'}) {
    $plugin_info{$plugname.'_last_group_state'} = 0;
    $plugin_info{$plugname.'_last_flipflop_state'} = 0;
  }
  $plugin_subscribe{$in_ga}{$plugname} = 1; # abonnieren auf Eingangs-GA
  $plugin_info{$plugname.'_cycle'} = 0; # nur für Telegramm
}

return;
