lib_src = [
  'dc_aheader.c',
  'dc_apeerstate.c',
  'dc_array.c',
  'dc_chat.c',
  'dc_chatlist.c',
  'dc_contact.c',
  'dc_dehtml.c',
  'dc_hash.c',
  'dc_imap.c',
  'dc_job.c',
  'dc_jobthread.c',
  'dc_key.c',
  'dc_keyring.c',
  'dc_loginparam.c',
  'dc_lot.c',
  'dc_move.c',
  'dc_context.c',
  'dc_configure.c',
  'dc_e2ee.c',
  'dc_imex.c',
  'dc_keyhistory.c',
  'dc_log.c',
  'dc_qr.c',
  'dc_receive_imf.c',
  'dc_securejoin.c',
  'dc_mimefactory.c',
  'dc_mimeparser.c',
  'dc_msg.c',
  'dc_openssl.c',
  'dc_param.c',
  'dc_pgp.c',
  'dc_saxparser.c',
  'dc_simplify.c',
  'dc_smtp.c',
  'dc_sqlite3.c',
  'dc_stock.c',
  'dc_strbuilder.c',
  'dc_strencode.c',
  'dc_token.c',
  'dc_tools.c',
]

lib_deps = [pthreads, zlib, openssl, sasl, sqlite, etpan, netpgp, math]
lib_inc = include_directories('.')
lib = library(
  'deltachat', lib_src,
  dependencies: lib_deps,
  include_directories: lib_inc,
  version: version,
  install: true,
)
dep = declare_dependency(
  include_directories: lib_inc,
  dependencies: lib_deps,
  link_with: [lib],
  version: version,
)
install_headers(['deltachat.h'],
                subdir: 'deltachat')


pkg = import('pkgconfig')
pkg.generate(libraries : lib,
             version : version,
             subdirs : ['deltachat'],
             name : 'libdeltachat',
             filebase : 'deltachat',
             description : 'Create your own, email-compatible messenger.')
