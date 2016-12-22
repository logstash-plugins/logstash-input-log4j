#!/usr/bin/perl

open(my $s, ">log4j-proxyproto.capture");
print $s "PROXY TCP4 1.2.3.4 127.0.0.1 12345 2456\r\n";
open(my $in, "<log4j.capture");
sysread($in, $dummy, 50000);
print $s $dummy;
close($in);
close($s);
