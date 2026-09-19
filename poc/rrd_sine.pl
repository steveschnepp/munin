#!/usr/bin/env perl
# Generate 4 months of perfect sine wave data in an RRD
use strict;
use warnings;
use RRDs;
use File::Temp qw(tempdir);
use POSIX qw(sin);

my $dir = tempdir(CLEANUP => 1);
my $rrd = "$dir/sine.rrd";

# 4 months at 5-minute resolution
# 4 * 30 * 24 * 12 = 34560 steps
my $STEP    = 300;           # 5 min
my $DAYS    = 120;           # 4 months
my $STEPS   = $DAYS * 24 * 12;  # 5-min intervals per day
my $T0      = 1_700_000_000; # fixed epoch (Nov 2023-ish)
my $END     = $T0 + $STEPS * $STEP;

# Sine params
my $BASE    = 500;           # centerline
my $AMP     = 200;           # amplitude
my $PERIOD  = 24 * 12;       # one cycle per day (in 5-min steps)

print "Creating RRD: $DAYS days, step=${STEP}s, $STEPS points\n";

RRDs::create($rrd,
    "--start", $T0,
    "--step",  $STEP,
    "DS:cpu:GAUGE:600:0:1000",
    "DS:mem:GAUGE:600:0:1000",
    "DS:net:GAUGE:600:0:1000",
    "RRA:AVERAGE:0.5:1:4032",   # 4 weeks at 5min
    "RRA:AVERAGE:0.5:12:4320",  # 90 days at 1hr
    "RRA:MIN:0.5:12:4320",
    "RRA:MAX:0.5:12:4320",
);
die "create: " . RRDs::error() if RRDs::error();

print "Writing $STEPS data points...";

my $t = $T0 + $STEP;
for my $i (0 .. $STEPS - 1) {
    my $phase = $i / $PERIOD;

    # cpu: daily cycle, peaks at noon
    my $cpu = $BASE + $AMP * sin(2 * 3.14159265 * $phase - 1.5708);  # -pi/2 so peak at noon

    # mem: slow drift upward with noise
    my $mem = 300 + 100 * $phase / $STEPS * $PERIOD + 30 * sin(2 * 3.14159265 * $phase * 2);

    # net: bursty, two peaks per day
    my $net = $BASE * 0.5 + $AMP * 0.8 * sin(2 * 3.14159265 * $phase * 2);

    RRDs::update($rrd, sprintf("%d:%.1f:%.1f:%.1f", $t, $cpu, $mem, $net));
    die "update[$i]: " . RRDs::error() if RRDs::error();
    $t += $STEP;
}

print " done\n";

# Verify: fetch last day
print "\n=== Last 24h (hourly avg) ===\n";
my @args = (
    "--start", $END - 86400,
    "--end",   $END,
    "--step",  3600,
    "DEF:cpu=$rrd:cpu:AVERAGE",
    "DEF:mem=$rrd:mem:AVERAGE",
    "DEF:net=$rrd:net:AVERAGE",
    "XPORT:cpu", "XPORT:mem", "XPORT:net",
);

my ($s, $e, $st, $n, $cols, $vals) = RRDs::xport(@args);
die "xport: " . RRDs::error() if RRDs::error();

printf "%-6s %8s %8s %8s\n", "hour", "cpu", "mem", "net";
print "-" x 36 . "\n";

for my $i (0 .. $#$vals) {
    my $row = $vals->[$i];
    my $hr = ($i % 24);
    printf "%02d:00  %7.1f  %7.1f  %7.1f\n", $hr,
        $row->[0] // 0, $row->[1] // 0, $row->[2] // 0;
}

# CDEF: total = cpu + mem + net
print "\n=== CDEF test: total = cpu + mem + net ===\n";
my @args2 = (
    "--start", $END - 86400,
    "--end",   $END,
    "--step",  3600,
    "DEF:c=$rrd:cpu:AVERAGE",
    "DEF:m=$rrd:mem:AVERAGE",
    "DEF:n=$rrd:net:AVERAGE",
    "CDEF:total=c,m,n,+,+",
    "XPORT:total",
);

my ($s2, $e2, $st2, $n2, $c2, $v2) = RRDs::xport(@args2);
die "xport: " . RRDs::error() if RRDs::error();

printf "%-6s %8s\n", "hour", "total";
print "-" x 16 . "\n";
for my $i (0 .. $#$v2) {
    printf "%02d:00  %7.1f\n", $i % 24, $v2->[$i][0] // 0;
}

print "\n=== Stats ===\n";
print "RRD file: $rrd\n";
print "Time range: $T0 to $END\n";
print "Steps: $STEPS\n";
print "Duration: $DAYS days\n";
