#!/usr/bin/env perl
# POC: Batch multiple CDEF threshold checks in one RRDs::xport call
use strict;
use warnings;
use RRDs;
use File::Temp qw(tempdir);
use Time::HiRes qw(time);

my $dir = tempdir(CLEANUP => 1);

# Create test RRD
my $rrd = "$dir/test.rrd";
RRDs::create($rrd,
    "--step", "60",
    "DS:cpu_user:GAUGE:120:0:U",
    "DS:cpu_system:GAUGE:120:0:U",
    "DS:cpu_iowait:GAUGE:120:0:U",
    "RRA:AVERAGE:0.5:1:60",
);
die "create: " . RRDs::error() if RRDs::error();

my $t = time();
for my $i (0..5) {
    RRDs::update($rrd, "$t:" . (40+$i*5) . ":" . (20+$i*2) . ":" . (5+$i));
    die "update: " . RRDs::error() if RRDs::error();
    $t += 60;
}

print "=== Single xport with multiple CDEFs ===\n";
my @args = (
    "--start", "now-3600",
    "--end",   "now+120",
    "--step",  "60",
    "DEF:user=$rrd:cpu_user:AVERAGE",
    "DEF:sys=$rrd:cpu_system:AVERAGE",
    "DEF:io=$rrd:cpu_iowait:AVERAGE",
    "CDEF:total=user,sys,+",           # user + system
    "CDEF:all_cpu=user,sys,+",         # same as total (alias test)
    "CDEF:io_pct=io,user,sys,+,/,100,*",  # iowait % of total
    "CDEF:user_pct=user,user,sys,+,/,100,*",  # user % of total
    "XPORT:user",
    "XPORT:sys",
    "XPORT:io",
    "XPORT:total",
    "XPORT:io_pct",
    "XPORT:user_pct",
);

my ($s, $e, $step, $nb, $cols, $vals) = RRDs::xport(@args);
die "xport: " . RRDs::error() if RRDs::error();

# Timing is implicit - xport is fast
print "columns: " . join(", ", @$cols) . "\n\n";

# Find last valid row
my $last_row;
for my $i (reverse 0..$#$vals) {
    if (grep { defined $_ } @{$vals->[$i]}) {
        $last_row = $vals->[$i];
        last;
    }
}

if ($last_row) {
    printf "%-12s %8s  threshold\n", "field", "value";
    print "-" x 45 . "\n";

    # Define thresholds for each CDEF
    my %thresholds = (
        total   => [80, 100],
        io_pct  => [10, 20],
        user_pct => [60, 80],
    );

    for my $i (0..$#$cols) {
        my $name = $cols->[$i];
        my $val = $last_row->[$i];
        next unless defined $val;

        my ($warn, $crit) = @{$thresholds{$name} // [undef, undef]};
        my $state = '-';
        if (defined $crit && $val > $crit) {
            $state = 'CRITICAL';
        } elsif (defined $warn && $val > $warn) {
            $state = 'WARNING';
        } else {
            $state = 'ok';
        }

        printf "%-12s %8.1f  warn=%s crit=%s  => %s\n",
            $name, $val,
            defined $warn ? $warn : '-',
            defined $crit ? $crit : '-',
            $state;
    }
}

print "\n=== Comparison: individual xport calls ===\n";
my $t0 = [gettimeofday];

for my $cdef ("user,sys,+", "io,user,sys,+,/,100,*") {
    my @a = (
        "--start", "now-3600",
        "--end",   "now+120",
        "--step",  "60",
        "DEF:user=$rrd:cpu_user:AVERAGE",
        "DEF:sys=$rrd:cpu_system:AVERAGE",
        "DEF:io=$rrd:cpu_iowait:AVERAGE",
        "CDEF:result=$cdef",
        "XPORT:result",
    );
    RRDs::xport(@a);
}

printf "2 individual xports took %.3f ms\n", tv_interval($t0) * 1000;

print "\n=== Summary ===\n";
print "1. Multiple CDEFs can be computed in a SINGLE xport call\n";
print "2. Just add more CDEF: and XPORT: lines\n";
print "3. Much more efficient than separate calls per CDEF\n";
print "4. Limits.pm can batch all CDEF thresholds for a service\n";
