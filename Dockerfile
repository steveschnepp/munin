FROM ubuntu:14.04
RUN apt-get update

RUN apt-get install -y \
  libdbd-pg-perl \
  libdbd-sqlite3-perl \
  libdbi-perl \
  libdevel-cover-perl \
  libdevel-nytprof-perl \
  libfile-copy-recursive-perl \
  libfile-readbackwards-perl \
  libfile-slurp-perl \
  libhtml-template-perl \
  libhtml-template-pro-perl \
  libhttp-server-simple-perl \
  libio-socket-inet6-perl \
  libio-stringy-perl \
  liblist-moreutils-perl \
  liblog-dispatch-perl \
  libmodule-build-perl \
  libnet-dns-perl \
  libnet-ip-perl \
  libnet-server-perl \
  libnet-snmp-perl \
  libnet-ssleay-perl \
  libparallel-forkmanager-perl \
  libparams-validate-perl \
  librrds-perl \
  libtest-class-perl \
  libtest-deep-perl \
  libtest-differences-perl \
  libtest-longstring-perl \
  libtest-mockmodule-perl \
  libtest-mockobject-perl \
  libtest-perl-critic-perl \
  liburi-perl \
  libwww-perl \
  libxml-dumper-perl \
  libxml-libxml-perl \
  libxml-parser-perl \
 \
  python-sphinx \
  rrdtool \
  sqlite3 \
