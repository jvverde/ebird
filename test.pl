#!/usr/bin/perl
use strict;
use warnings;

local $/="\n\n";
$\ ="\n";
my $re = qr/^(.+) \((.+)\) (?:\((\d+)\))?.*?\n\s*- Reported (.+ \d{2}:\d{2}) by (.+)\s*?\n\s*- (.+)\s*?\n\s*- Map: (http:\/\/[^\s]+)\s*?\n\s*- Checklist: (https:\/\/ebird.org\/checklist\/[^\s]+)/m;
$re = qr/^(.+) \(([A-Z][a-z]+ [a-z]+)[^\d]*\)(?: \((\d+)\))?.*\n\s*- Reported (.+ \d{2}:\d{2}) by (.+)\s*?\n\s*- (.+)\s*?\n\s*- Map: (http:\/\/[^\s]+)\s*?\n\s*- Checklist: (https:\/\/ebird.org\/checklist\/[^\s]+)/m;

while (my $str = <>){
  $str =~ $re;
  print "1:$1" if defined $1;
  print "2:$2" if defined $2;
  print "3:$3" if defined $3;
  print "4:$4" if defined $4;
  print "5:$5" if defined $5;
  print "6:$6" if defined $6;
  print "7:$7" if defined $7;
  print "8:$8" if defined $8;
  print "9:$9" if defined $9;
}
