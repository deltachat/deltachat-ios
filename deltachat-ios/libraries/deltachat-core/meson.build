project(
  'deltachat-core', 'c',
  license: 'GPLv3',
  subproject_dir: 'libs',
)


# These get their information from pkg-config.
pthreads = dependency('threads')
zlib = dependency('zlib')
openssl = dependency('openssl')
sasl = dependency('libsasl2')
sqlite = dependency('sqlite3')


# Optionally use the system libetpan
if get_option('system-etpan')
  # Sadly libetpan doesn't use pkg-config.
  etpan_prefix = run_command('libetpan-config', ['--prefix']).stdout().strip()
  etpan_cflags = run_command('libetpan-config', ['--cflags']).stdout().strip().split()
  etpan_libs = run_command('libetpan-config', ['--libs']).stdout().strip().split()
  etpan_inc_dir = join_paths(etpan_prefix, 'include')
  etpan_inc = include_directories(etpan_inc_dir)
  etpan = declare_dependency(
    compile_args: etpan_cflags,
    include_directories: etpan_inc,
    link_args: etpan_libs,
  )
else
  etpan_proj = subproject('libetpan')
  etpan = etpan_proj.get_variable('dep')
endif


# Build bundled dependencies.
netpgp_proj = subproject('netpgp')
netpgp = netpgp_proj.get_variable('dep')


# Build the library, stored in lib`.
subdir('src')


# Build the binaries.
subdir('cmdline')


version = run_command('git', 'describe', '--tags')
if version.returncode() != 0
  message('git version not found, pkg-config will not be generated')
else
  pkg = import('pkgconfig')
  pkg.generate(libraries : lib,
               version : version.stdout().strip(),
               subdirs : ['deltachat'],
               name : 'libdeltachat',
               filebase : 'deltachat',
               description : ' Create your own, email-compatible messenger.')
endif
