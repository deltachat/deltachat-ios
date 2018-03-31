project('netpgp', 'c')

# pkg-config dependencies
zlib = dependency('zlib')
openssl = dependency('openssl')
pthreads = dependency('threads')

# Dependencies without pkg-config, just try linking against them
compiler = meson.get_compiler('c')
bzip2 = compiler.find_library('bz2')


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
inc = include_directories('include')


lib = library(
  'netpgp', src,
  dependencies: [zlib, bzip2, openssl, pthreads],
  include_directories: inc,
  install: true,
)

dep = declare_dependency(
  include_directories: inc,
  link_with: lib,
)
