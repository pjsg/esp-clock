#!/usr/bin/perl
#
use strict;

while (my $fn = shift @ARGV) {
  open(IN, "<$fn");
  binmode(IN);
  $fn =~ s/\./_/g;
  open(OUT, ">$fn.lua");

  print OUT "return \"";

  while (<IN>) {
    foreach my $char (split(//, $_)) {
      printf OUT "\\%03d", ord($char);
    }
  }

  print OUT "\"\n";
}
