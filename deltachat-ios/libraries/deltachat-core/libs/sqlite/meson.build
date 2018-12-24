project('sqlite', 'c',
        version: '3.23.1',
        license: 'SQLite')

pthreads = dependency('threads')

add_project_arguments('-DNULL=0',
                      '-DSOCKLEN_T=socklen_t',
                      '-DLOCALE_NOT_USED',
                      '-D_LARGEFILE_SOURCE=1',
                      '-D_FILE_OFFSET_BITS=64',
                      '-DSQLITE_OMIT_LOAD_EXTENSION',
                      '-DSQLITE_MAX_MMAP_SIZE=0',
                      '-DSQLITE_OMIT_WAL',
                      language: 'c')

# Silence warnings, we don't own this subproject
cc = meson.get_compiler('c')
ccargs = cc.get_supported_arguments(['-Wno-unused-function'])

if get_option('static-pic-lib')
  lib = static_library(
    'sqlite', ['sqlite3.c'],
    c_args: ccargs,
    pic: true,
    dependencies: [pthreads],
  )
else
  if get_option('default_library') != 'static'
    error('Only --default-library=static is supported for now')
  endif
  lib = library(
    'sqlite', ['sqlite3.c'],
    c_args: ccargs,
    dependencies: [pthreads],
  )
endif

dep = declare_dependency(
  include_directories: include_directories('.'),
  link_with: lib,
)
