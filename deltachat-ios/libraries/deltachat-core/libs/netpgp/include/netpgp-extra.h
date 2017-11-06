#ifndef __NETPGP_EXTRA_H__
#define __NETPGP_EXTRA_H__

#include "netpgp/config-netpgp.h"
#include "netpgp/packet-parse.h"
#include "netpgp/errors.h"
#include "netpgp/defs.h"
#include "netpgp/crypto.h"
#include "netpgp/create.h"
#include "netpgp/signature.h"
#include "netpgp/readerwriter.h"
#include "netpgp/validate.h"
#include "netpgp/netpgpsdk.h"
unsigned rsa_generate_keypair(pgp_key_t *keydata, const int numbits, const unsigned long e, const char *hashalg, const char *cipher);

#endif // __NETPGP_EXTRA_H__
