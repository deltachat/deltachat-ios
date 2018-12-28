project('cyrussasl', 'c',
        version: '2.1.25',
        license: 'CMU libsasl')

openssl = dependency('openssl', fallback: ['openssl', 'dep'])

src = [
  'lib/auxprop.c',
  'lib/canonusr.c',
  'lib/checkpw.c',
  'lib/client.c',
  'lib/common.c',
  'lib/config.c',
  'lib/dlopen.c',
  'lib/external.c',
  'lib/getsubopt.c',
  'lib/md5.c',
  'lib/saslutil.c',
  'lib/server.c',
  'lib/seterror.c',
  'lib/snprintf.c',
  'plugins/anonymous.c',
  'plugins/anonymous_init.c',
  'plugins/cram.c',
  'plugins/crammd5_init.c',
  'plugins/digestmd5.c',
  'plugins/digestmd5_init.c',
  'plugins/login.c',
  'plugins/login_init.c',
  'plugins/ntlm.c',
  'plugins/ntlm_init.c',
  'plugins/otp.c',
  'plugins/otp_init.c',
  'plugins/passdss.c',
  'plugins/passdss_init.c',
  'plugins/plain.c',
  'plugins/plain_init.c',
  'plugins/plugin_common.c',
  'plugins/scram.c',
  'plugins/scram_init.c',
  'plugins/srp.c',
  'plugins/srp_init.c',
]
inc = include_directories(
  'include',
  'include/sasl',
  'plugins',
)

# Silence warnings, we don't own this subproject
cc = meson.get_compiler('c')
ccargs = cc.get_supported_arguments(
  [
    '-Wno-discarded-qualifiers',
    '-Wno-format',
    '-Wno-incompatible-pointer-types',
    '-Wno-nonnull-compare',
    '-Wno-parentheses-equality',
    '-Wno-pointer-sign',
    '-Wno-sometimes-uninitialized',
    '-Wno-tautological-compare',
    '-Wno-unused-but-set-variable',
    '-Wno-unused-const-variable',
    '-Wno-unused-const-variable',
    '-Wno-unused-function',
    '-Wno-unused-variable',
  ]
)

if get_option('static-pic-lib')
  lib = static_library(
    'sasl2', src,
    c_args: ccargs,
    pic: true,
    include_directories: inc,
    dependencies: [openssl],
  )
else
  if get_option('default_library') != 'static'
    error('Only --default-library=static is supported for now')
  endif
  lib = library(
    'sasl2', src,
    c_args: ccargs,
    include_directories: inc,
    dependencies: [openssl],
  )
endif

dep = declare_dependency(
  include_directories: include_directories('include'),
  link_with: lib,
)
