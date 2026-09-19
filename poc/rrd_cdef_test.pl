#!/usr/bin/env perl
use strict;
use warnings;
use RRDs;
use File::Temp qw(tempfile tempdir);
use Data::Dumper;

my $dir = tempdir(CLEANUP => 1);
my $rrd = "$dir/test.rrd";

# Create RRD with two DS
RRDs::create($rrd,
    "--step", "60",
    "DS:input:GAUGE:120:0:U",
    "DS:output:GAUGE:120:0:U",
    "RRA:AVERAGE:0.5:1:60",
);
die "create failed: " . RRDs::error() if RRDs::error();

# Update with some data - go forward in time from 10 minutes ago
my $start_time = time() - 600;
for my $i (0..5) {
    my $t = $start_time + $i*60 + 1;  # +1 to avoid step issues
    RRDs::update($rrd, "$t:100:50");
    die "update failed: " . RRDs::error() if RRDs::error();
}

print "=== Test 1: RRDs::fetch (raw DS) ===\n";
my ($start,$end,$step,$names,$data) = RRDs::fetch($rrd, "AVERAGE", "-s", "e-10m");
print "start=$start end=$end step=$step\n";
print "names: " . join(", ", @$names) . "\n";
for my $row (@$data) {
    print join(", ", map { defined $_ ? sprintf("%.2f", $_) : "NaN" } @$row) . "\n";
}

print "\n=== Test 2: RRDs::graphv (with CDEF) ===\n";
# Use graphv to compute a CDEF value
my $img = "$dir/test.png";
my $v = RRDs::graphv($img,
    "--start", "e-10m",
    "--end", "now",
    "--width", "100",
    "--height", "50",
    "DEF:in=$rrd:input:AVERAGE",
    "DEF:out=$rrd:output:AVERAGE",
    "CDEF:total=in,out,+",
    "PRINT:total:AVERAGE:%.2lf",
);
if (RRDs::error()) {
    print "graphv error: " . RRDs::error() . "\n";
} else {
    print "graphv result:\n";
    print Dumper($v);
}

print "\n=== Test 3: RRDs::xport (with CDEF) ===\n";
my $xport = RRDs::xport(
    "--start", "e-10m",
    "--end", "now",
    "--step", "60",
    "DEF:in=$rrd:input:AVERAGE",
    "DEF:out=$rrd:output:AVERAGE",
    "CDEF:total=in,out,+",
    "XPORT:in",
    "XPORT:out",
    "XPORT:total",
);
if (RRDs::error()) {
    print "xport error: " . RRDs::error() . "\n";
} else {
    print "xport result:\n";
    print Dumper($xport);
}

print "\n=== Test 4: RRDs::graph with PRINT to stdout ===\n";
# Redirect stdout to capture PRINT output
close STDOUT;
open STDOUT, ">", \my $stdout_buf or die "Cannot redirect stdout: $!";
RRDs::graph("/dev/null",
    "--start", "e-10m",
    "--end", "now",
    "--width", "100",
    "--height", "50",
    "DEF:in=$rrd:input:AVERAGE",
    "DEF:out=$rrd:output:AVERAGE",
    "CDEF:total=in,out,+",
    "PRINT:total:AVERAGE:val=%lf",
    "PRINT:total:MAX:max=%lf",
);
close STDOUT;
open STDOUT, ">&STDERR" or die;
if (RRDs::error()) {
    print "graph error: " . RRDs::error() . "\n";
} else {
    print "graph PRINT output:\n$stdout_buf\n";
}

print "\n=== Test 5: Compute CDEF value for threshold check ===\n";
# The real use case: get the last CDEF value for threshold comparison
my $last_total;
{
    my ($s,$e,$st,$n,$d) = RRDs::fetch($rrd, "AVERAGE", "-s", "e-5m", "-e", "now");
    # Find the 'total' column - we need to compute it ourselves
    # since fetch doesn't support CDEFs
    my @in_idx = grep { $n->[$_] eq 'input' } 0..$#$n;
    my @out_idx = grep { $n->[$_] eq 'output' } 0..$#$n;
    
    # Get last non-NaN values
    my ($last_in, $last_out);
    for my $row (reverse @$d) {
        $last_in //= $row->[$in_idx[0]] if defined $row->[$in_idx[0]];
        $last_out //= $row->[$out_idx[0]] if defined $row->[$out_idx[0]];
        last if defined $last_in && defined $last_out;
    }
    
    if (defined $last_in && defined $last_out) {
        $last_total = $last_in + $last_out;
        print "Computed total = input($last_in) + output($last_out) = $last_total\n";
    } else {
        print "Could not compute total: in=$last_in out=$last_out\n";
    }
}

print "\n=== Summary ===\n";
print "1. RRDs::fetch: Gets raw DS values, no CDEF support\n";
print "2. RRDs::graphv PRINT: Can compute CDEFs, returns hash\n";
print "3. RRDs::xport: Can export with CDEFs, returns hash\n";
print "4. RRDs::graph PRINT: Can compute CDEFs, prints to stdout\n";
print "5. For threshold check: Use graphv PRINT or compute manually from fetch\n";
