#!/bin/bash

cp_sources()
{
	SRCDIR=$1
	CDIR=$2
	mkdir -p               libetpan/$CDIR/
	cp $SRCDIR/$CDIR/*.c   libetpan/$CDIR/ 2>/dev/null
	cp $SRCDIR/$CDIR/*.h   libetpan/$CDIR/ 2>/dev/null
	cp $SRCDIR/$CDIR/TODO* libetpan/$CDIR/ 2>/dev/null
}

update_libetpan() {
	SRCDIR=$1
	pushd .
	cd $SRCDIR

	( ./autogen.sh --enable-iconv )
	make

	popd
	
	# copy docs

	rm                   libetpan/*
	cp $SRCDIR/COPYRIGHT libetpan/

	# copy source
	
	rm -r libetpan/src/*
	
	cp_sources $SRCDIR "src/data-types"
	cp_sources $SRCDIR "src/driver"
	cp_sources $SRCDIR "src/driver/implementation/data-message"
	cp_sources $SRCDIR "src/driver/implementation/db"
	cp_sources $SRCDIR "src/driver/implementation/feed"
	cp_sources $SRCDIR "src/driver/implementation/hotmail"
	cp_sources $SRCDIR "src/driver/implementation/imap"
	cp_sources $SRCDIR "src/driver/implementation/maildir"
	cp_sources $SRCDIR "src/driver/implementation/mbox"
	cp_sources $SRCDIR "src/driver/implementation/mh"
	cp_sources $SRCDIR "src/driver/implementation/mime-message"
	cp_sources $SRCDIR "src/driver/implementation/nntp"		
	cp_sources $SRCDIR "src/driver/implementation/pop3"		
	cp_sources $SRCDIR "src/driver/interface"
	cp_sources $SRCDIR "src/driver/tools"
	cp_sources $SRCDIR "src/engine"
	cp_sources $SRCDIR "src/low-level/feed"
	cp_sources $SRCDIR "src/low-level/imap"
	cp_sources $SRCDIR "src/low-level/imf"
	cp_sources $SRCDIR "src/low-level/maildir"
	cp_sources $SRCDIR "src/low-level/mbox"
	cp_sources $SRCDIR "src/low-level/mh"
	cp_sources $SRCDIR "src/low-level/mime"
	cp_sources $SRCDIR "src/low-level/nntp"
	cp_sources $SRCDIR "src/low-level/pop3"
	cp_sources $SRCDIR "src/low-level/smtp"
	cp_sources $SRCDIR "src/main"

	rm libetpan/src/driver/tools/*.c
	rm libetpan/src/engine/mailprivacy_gnupg.c
	rm libetpan/src/engine/mailprivacy_smime.c
	rm libetpan/src/low-level/feed/*.c
	rm libetpan/src/low-level/maildir/*.c
	rm libetpan/src/low-level/mbox/*.c
	rm libetpan/src/low-level/mh/*.c
	rm libetpan/src/low-level/nntp/*.c
	rm libetpan/src/low-level/pop3/*.c

	# copy includes 
	# (in the include directory there are just links to the source directory)

	rm -r libetpan/include/*
	
	cp    $SRCDIR/libetpan-config.h    libetpan/libetpan-config.h
	mkdir -p                           libetpan/include/libetpan/
	cp -a $SRCDIR/include/libetpan/*.h libetpan/include/libetpan/
	cp    $SRCDIR/config.h             libetpan/include/libetpan/
	
}

if [ -n "$1" ]; then 
	update_libetpan $1
else
	echo "usage: update-libetpan <source-path>"
fi


