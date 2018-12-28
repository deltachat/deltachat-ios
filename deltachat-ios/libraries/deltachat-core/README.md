# Delta Chat Core Library

[![Build Status](https://travis-ci.org/deltachat/deltachat-core.svg?branch=master)](https://travis-ci.org/deltachat/deltachat-core)

The _Delta Chat Core Library_ is written in cross-platform **C**,
documented at <https://c.delta.chat>.  

The ``deltachat`` Python bindings can be found in the 
[python subdirectory](https://github.com/deltachat/deltachat-core/tree/master/python)
and are documented at <https://py.delta.chat>.

## binary/distribution packages  (work-in-progress)

There are work-in-progress efforts for creating (binary) packages which
do not require that you build the library manually:

- [libdeltachat-core-git archlinux package](https://aur.archlinux.org/packages/libdeltachat-core-git/>)

- [Debian packaging](https://github.com/deltachat/deltachat-core/issues/299)

- [Windows building](https://github.com/deltachat/deltachat-core/issues/306)

If you can help with advancing or adding to these efforts, be our guest. 
Otherwise read on for how to get ``libdeltachat.so`` and ``deltachat.h``
installed into your system. 

## building your own ``libdeltachat.so``

### getting a recent enough ``meson`` for building 

If you have installed ``meson`` in your environment check the version::

    meson --version
   
You need to have version ``0.47.2`` at least. If the version
is older there is a recommended way of getting a better version:

1. uninstall your system-level ``meson`` package (if possible)

2. ensure you have at least ``python3.5`` installed and type:
   ```
       python3 -m pip 
   ```

   to check that you have "pip" installed. If not available, you
   might get it as a ``python3-pip`` package or you could follow
   [installing pip](https://pip.pypa.io/en/stable/installing/).

3. then pip-install meson into your home-directory:
   ```
       python3 -u -m pip install meson
   ```

   the ``-u`` causes the pip-install to put a ``meson`` command line tool into
   ``~/.local/`` or %APPDATA%\Python on Windows.  

4. run ``meson --version`` to verify it's at at least version 0.48.0 now.
   If the ``meson`` command is not found, add ``~/.local/bin`` to ``PATH``
   and try again (``export PATH=~/.local/bin:$PATH`` on many unix-y terminals).


### installing "ninja-build" 

On Linux and Mac you need to install 'ninja-build' (debian package name)
to be able to actually build/compile things. 

Note that most dependencies below are detected using
[pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/).
Usually this just works automatically, provided the depending libraries
are installed correctly.  

### installing c-level dependencies 

The deltachat core library depends on a number of external libraries,
which you may need to install (we have some fallbacks if you don't):

- [LibEtPan](https://github.com/dinhviethoa/libetpan); Note that this
  library does not use pkg-config so the system-provided version will
  be looked up by using `libetpan-config` which must be in the PATH.
  Version 1.8 or newer is required. LibEtPan must be compiled with
  SASL support enabled.

- [OpenSSL](https://www.openssl.org/)

- [SQLite](https://sqlite.org/)

- [zlib](https://zlib.net)

- [libsasl](https://cyrusimap.org/sasl/)

To install these on debian you can type:
```
    sudo apt install libetpan-dev libssl-dev libsqlite3-dev libsasl2-dev libbz2-dev zlib1g-dev
```


### performing the actual build 

Once all dependencies are installed, creating a build is as follows,
starting from a [deltachat-core github checkout](https://github.com/deltachat/deltachat-core):

```
mkdir builddir
cd builddir
meson
# Optionally configure some other parameters
# run `meson configure` to see the options, e.g.
#    meson configure --default-library=static
ninja
sudo ninja install
sudo ldconfig
```

The install keeps a log of which files were installed. Uninstalling
is thus also supported:
```
sudo ninja uninstall
```
**NOTE** that the above assumes `/usr/local/lib` is configured somewhere
in `/etc/ld.so.conf` or `/etc/ld.so.conf.d/*`, which is fairly
standard.  It is possible your system uses
`/usr/local/lib/x86_64-linux-gnu` which should be auto-detected and
just work as well.


### Building without system-level dependencies 

By default stripped-down versions of the dependencies are bundled with
Delta Chat Core and these will be used when a dependency is missing.
You can choose to always use the bundled version of the dependencies
by invoking meson with the `--wrap-mode=forcefallback` option.
Likewise you can forbid using the bundled dependencies using
`--wrap-mode=nofallback`.

There also is an experimental feature where you can build a version of the
shared `libdeltachat.so` library with no further external
dependencies.  This can be done by passing the `-Dmonolith=true`
option to meson.  Note that this implies `--wrap-mode=forcefallback`
since this will always use all the bundled dependencies.


## Language bindings and frontend Projects

Language bindings are available for:

- [Node.js](https://www.npmjs.com/package/deltachat-node)
- [Python](https://py.delta.chat)
- **Java** and **Swift** (contained in the Android/iOS repos) 

The following "frontend" project make use of the C-library
or its language bindings: 

- [Android](https://github.com/deltachat/deltachat-android)
- [iOS](https://github.com/deltachat/deltachat-ios) 
- [Desktop](https://github.com/deltachat/deltachat-desktop)
- [Pidgin](https://gitlab.com/lupine/purple-plugin-delta)

## Testing program

After a successful build there is also a little testing program in `builddir/cmdline`.
You start the program with `./delta <database-file>`
(if the database file does not exist, it is created).
The program then shows a prompt and typing `help` gives some help about the available commands.

New tests are currently developed using Python, see 
https://github.com/deltachat/deltachat-core/tree/master/python/tests


## License

Licensed under the MPL 2.0 see [LICENSE](./LICENSE) file for details.

Copyright © 2017, 2018 Björn Petersen and Delta Chat contributors.
