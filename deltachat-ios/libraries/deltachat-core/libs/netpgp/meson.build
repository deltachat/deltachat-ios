project('netpgp', 'c',
        version: '20140220',
        license: '2-part BSD',
        default_options: ['c_std=gnu99'])

cc = meson.get_compiler('c')


## dependencies
pthreads = dependency('threads')
zlib = dependency('zlib', fallback: ['zlib', 'zlib_dep'])
openssl = dependency('openssl', fallback: ['openssl', 'dep'])

# BZip2 has no pkg-config, just try linking against it
bzip2 = cc.find_library('bz2', required: get_option('bzip2'))


## Build the #defines for config.h
config_h = configuration_data()
config_h.set_quoted('PACKAGE_BUGREPORT',
                    'Floris Bruynooghe <flub+delta@devork.be>')
config_h.set_quoted('PACKAGE_VERSION', meson.project_version())
config_h.set('HAVE_ZLIB_H', zlib.type_name() == 'internal'
                            or cc.has_header('zlib.h', dependencies: zlib))
config_h.set('HAVE_BZLIB_H', not get_option('bzip2').disabled()
                             and cc.has_header('bzlib.h', dependencies: bzip2))

sys_headers = [
  ['CommonCrypto/CommonDigest.h', 'HAVE_COMMONCRYPTO_COMMONDIGEST_H'],
  ['direct.h', 'HAVE_DIRECT_H'],
  ['errno.h', 'HAVE_ERRNO_H'],
  ['fcntl.h', 'HAVE_FCNTL_H'],
  ['inttypes.h', 'HAVE_INTTYPES_H'],
  ['limits.h', 'HAVE_LIMITS_H'],
  ['stdint.h', 'HAVE_STDINT_H'],
  ['sys/cdefs.h', 'HAVE_SYS_CDEFS_H'],
  ['sys/mman.h', 'HAVE_SYS_MMAN_H'],
  ['sys/param.h', 'HAVE_SYS_PARAM_H'],
  ['termios.h', 'HAVE_TERMIOS_H'],
  ['unistd.h', 'HAVE_UNISTD_H'],
]
foreach hdr: sys_headers
  config_h.set(hdr.get(1), cc.has_header(hdr.get(0)) )
endforeach

ssl_headers = [
  ['openssl/aes.h', 'HAVE_OPENSSL_AES_H'],
  ['openssl/bn.h', 'HAVE_OPENSSL_BN_H'],
  ['openssl/camellia.h', 'HAVE_OPENSSL_CAMELLIA_H'],
  ['openssl/cast.h', 'HAVE_OPENSSL_CAST_H'],
  ['openssl/des.h', 'HAVE_OPENSSL_DES_H'],
  ['openssl/dsa.h', 'HAVE_OPENSSL_DSA_H'],
  ['openssl/err.h', 'HAVE_OPENSSL_ERR_H'],
  ['openssl/idea.h', 'HAVE_OPENSSL_IDEA_H'],
  ['openssl/md5.h', 'HAVE_OPENSSL_MD5_H'],
  ['openssl/rand.h', 'HAVE_OPENSSL_RAND_H'],
  ['openssl/rsa.h', 'HAVE_OPENSSL_RSA_H'],
  ['openssl/sha.h', 'HAVE_OPENSSL_SHA_H'],
]
foreach hdr: ssl_headers
  config_h.set(hdr.get(1),
               openssl.type_name() == 'internal'
               or cc.has_header(hdr.get(0), dependencies: openssl))
endforeach

if (get_option('openssl-camellia').enabled()
    and not config_h.get('HAVE_OPENSSL_CAMELLIA_H'))
  error('OpenSSL camellia feature is enabled but not found')
endif
if get_option('openssl-camellia').disabled()
  config_h.set('OPENSSL_NO_CAMELLIA', true)
  config_h.set('HAVE_OPENSSL_CAMELLIA_H', false)
endif
if (get_option('openssl-idea').enabled()
    and not config_h.get('HAVE_OPENSSL_IDEA_H'))
  error('OpenSSL idea feature is enabled but not found')
endif
if get_option('openssl-idea').disabled()
  config_h.set('OPENSSL_NO_IDEA', true)
  config_h.set('HAVE_OPENSSL_IDEA_H', false)
endif

configure_file(output: 'config-netpgp-meson.h', configuration: config_h)
add_project_arguments('-DHAVE_CONFIG_MESON', language: 'c')


## The source code
src = [
  'src/compress.c',
  'src/create.c',
  'src/crypto.c',
  'src/keyring.c',
  'src/misc.c',
  'src/openssl_crypto.c',
  'src/packet-parse.c',
  'src/packet-show.c',
  'src/reader.c',
  'src/signature.c',
  'src/symmetric.c',
  'src/validate.c',
  'src/writer.c',
]

# The includes are messy:
# - include: The normal public header files
# - .: To find the config-netpgpg-meson.h by include/netpgp/config-netpgp.h
inc = include_directories('include', '.')


## Silence things if this is used as a subproject
ccargs = []
if meson.is_subproject()
  ccargs += cc.get_supported_arguments(['-Wno-misleading-indentation'])
endif


## Build the library
lib_deps = [pthreads, zlib, openssl, bzip2]
if get_option('static-pic-lib')
  lib = static_library(
    'netpgp', src,
    c_args: ccargs,
    pic: true,
    dependencies: lib_deps,
    include_directories: inc,
  )
else
  lib = library(
    'netpgp', src,
    c_args: ccargs,
    dependencies: lib_deps,
    include_directories: inc,
  )
endif

dep = declare_dependency(
  include_directories: inc,
  dependencies: lib_deps,
  link_with: lib,
)
