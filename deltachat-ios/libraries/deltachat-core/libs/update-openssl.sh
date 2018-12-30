#!/bin/bash

echo this is work-in-progress and not yet working!
exit

cp_sources()
{
	SRCDIR=$1
	CDIR=$2
	mkdir -p               openssl/$CDIR/
	cp $SRCDIR/$CDIR/*.c   openssl/$CDIR/ 2>/dev/null
	cp $SRCDIR/$CDIR/*.h   openssl/$CDIR/
}

update_openssl() {
	SRCDIR=$1
	pushd .
	cd $SRCDIR

	( ./config.sh )
	make

	popd
	
	rm -r openssl/crypto/*
	
	cp_sources $SRCDIR "crypto/aes"
	cp_sources $SRCDIR "crypto/asn1"
	cp_sources $SRCDIR "crypto/bf"
	cp_sources $SRCDIR "crypto/bio"
	cp_sources $SRCDIR "crypto/bn"
	cp_sources $SRCDIR "crypto/buffer"
	cp_sources $SRCDIR "crypto/camellia"
	cp_sources $SRCDIR "crypto/cast"
	cp_sources $SRCDIR "crypto/cmac"
	cp_sources $SRCDIR "crypto/comp"
	cp_sources $SRCDIR "crypto/conf"
	cp_sources $SRCDIR "crypto/des"
	cp_sources $SRCDIR "crypto/dh"
	cp_sources $SRCDIR "crypto/dsa"
	cp_sources $SRCDIR "crypto/dso"
	cp_sources $SRCDIR "crypto/ec"
	# missing: ecdh, ecdsa
	cp_sources $SRCDIR "crypto/err"
	cp_sources $SRCDIR "crypto/evp"
	cp_sources $SRCDIR "crypto/hmac"
	# missing: krb5
	cp_sources $SRCDIR "crypto/idea"
	cp_sources $SRCDIR "crypto/lhash"
	cp_sources $SRCDIR "crypto/md4"
	cp_sources $SRCDIR "crypto/md5"
	cp_sources $SRCDIR "crypto/modes"
	cp_sources $SRCDIR "crypto/objects"
	cp_sources $SRCDIR "crypto/ocsp"
	cp_sources $SRCDIR "crypto/pem"
	cp_sources $SRCDIR "crypto/pkcs12"
	cp_sources $SRCDIR "crypto/pkcs7"
	# missing pqueue
	cp_sources $SRCDIR "crypto/rand"
	cp_sources $SRCDIR "crypto/rc2"
	cp_sources $SRCDIR "crypto/rc4"
	cp_sources $SRCDIR "crypto/ripemd"
	cp_sources $SRCDIR "crypto/rsa"
	cp_sources $SRCDIR "crypto/sha"
	cp_sources $SRCDIR "crypto/srp"
	cp_sources $SRCDIR "crypto/stack"
	cp_sources $SRCDIR "crypto/store"
	cp_sources $SRCDIR "crypto/ts"
	cp_sources $SRCDIR "crypto/txt_db"
	cp_sources $SRCDIR "crypto/ui"
	cp_sources $SRCDIR "crypto/x509"
	cp_sources $SRCDIR "crypto/x509v3"
	
	
	# includes
	############################################################################

	rm -r openssl/include/*

	cp_sources $SRCDIR "include/openssl" 
}

if [ -n "$1" ]; then 
	update_openssl $1
else
	echo "usage: update-openssl <source-path>"
fi


