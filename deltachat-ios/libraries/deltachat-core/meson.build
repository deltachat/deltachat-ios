project(
  'deltachat-core', 'c',
  license: 'GPLv3',
  subproject_dir: 'libs',
)


# These get their information from pkg-config.
zlib = dependency('zlib')
openssl = dependency('openssl')
pthreads = dependency('threads')
sasl = dependency('libsasl2')
sqlite = dependency('sqlite3')

# Sadly libetpan doesn't use pkg-config.
etpan_prefix = run_command('libetpan-config', ['--prefix']).stdout().strip()
etpan_cflags = run_command('libetpan-config', ['--cflags']).stdout().strip().split()
etpan_libs = run_command('libetpan-config', ['--libs']).stdout().strip().split()
etpan_inc_dir = join_paths(etpan_prefix, 'include')
etpan_inc = include_directories(etpan_inc_dir)
if etpan_cflags == ''
  etpan = declare_dependency(
    include_directories: etpan_inc,
    link_args: etpan_libs,
  )
else
  etpan = declare_dependency(
    compile_args: etpan_cflags,
    include_directories: etpan_inc,
    link_args: etpan_libs,
  )
endif

# Build bundled dependencies.
netpgp_proj = subproject('netpgp')
netpgp = netpgp_proj.get_variable('dep')

# Build the library, stored in `lib`.
subdir('src')

# Build the binaries.
subdir('cmdline')
