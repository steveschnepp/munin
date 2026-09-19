#!/usr/bin/env perl
# POC: Use RRDs::xport to compute CDEF values for threshold checking
use strict;
use warnings;
use RRDs;
use File::Temp qw(tempdir);

my $dir = tempdir(CLEANUP => 1);
my $rrd = "$dir/test.rrd";

print "=== Creating RRD ===\n";
RRDs::create($rrd,
    "--step", "60",
    "DS:input:GAUGE:120:0:U",
    "DS:output:GAUGE:120:0:U",
    "RRA:AVERAGE:0.5:1:60",
);
die "create: " . RRDs::error() if RRDs::error();

# Update from "now" forward — RRD allows updates >= last_update
# First update sets the baseline; subsequent updates must be > previous
print "\n=== Updating ===\n";
my $t = time();  # start from now

for my $i (0..9) {
    my $in  = 100 + $i * 10;
    my $out = 50  + $i * 5;
    RRDs::update($rrd, "$t:$in:$out");
    die "update[$i]: " . RRDs::error() if RRDs::error();
    printf "  %-20s  in=%-4d  out=%-4d\n", scalar(localtime($t)), $in, $out;
    $t += 60;
}

# Now fetch back the last 10 minutes
print "\n=== RRDs::xport with CDEF ===\n";
my @args = (
    "--start", "now-600",
    "--end",   "now",
    "--step",  "60",
    "DEF:in=$rrd:input:AVERAGE",
    "DEF:out=$rrd:output:AVERAGE",
    "CDEF:total=in,out,+",
    "XPORT:in",
    "XPORT:out",
    "XPORT:total",
);

my ($start, $end, $step, $nb_vars, $cols, $vals) = RRDs::xport(@args);
die "xport: " . RRDs::error() if RRDs::error();

printf "%-8s %8s %8s %8s\n", "time", "in", "out", "total";
print "-" x 40 . "\n";

for my $i (0 .. $#$vals) {
    my $row = $vals->[$i];
    my @v = map { defined $_ ? sprintf("%8.1f", $_) : "     NaN" } @$row;
    printf "%-8s %s\n", scalar(localtime($start + $i * $step)), join(" ", @v);
}

# Threshold check on CDEF
my $last = $vals->[-1];
my $cdef_val = $last->[2];  # total is 3rd XPORT column

print "\n=== Threshold check on CDEF ===\n";
if (defined $cdef_val) {
    printf "Last total = %.1f\n", $cdef_val;
    my ($warn, $crit) = (170, 200);
    my $state = 'ok';
    $state = 'warning' if $cdef_val > $warn;
    $state = 'critical' if $cdef_val > $crit;
    printf "warning=%.0f  critical=%.0f  =>  %s\n", $warn, $crit, $state;
} else {
    print "Last total = NaN (no data)\n";
}

print "\n=== DONE ===\n";
