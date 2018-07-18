Delta Chat Core Library
================================================================================

You can use the _Delta Chat Core Library_ to build **your own messenger** or
plugin that is completely **compatible** with the existing email infrastructure.

![Logo](https://delta.chat/assets/features/start-img4.png)

Using this library in your app, you get the **ease** of well-known messengers
with the **reach** of email. Moreover, you're **independent** from other companies or
services as your data is not relayed through Delta Chat, only your email
provider. That means that there are no Delta Chat servers, only clients made compatible via Delta Chat Core.

The library is used eg. in the [Delta Chat Android Frontend](https://github.com/deltachat/deltachat-android)
and in the [Delta Chat iOS Frontend](https://github.com/deltachat/deltachat-ios), but can also be used for
completely different messenger projects.

Some features at a glance:

- **Secure** with automatic end-to-end-encryption, supporting the new
  [Autocrypt](https://autocrypt.org/) standard
- **Fast** by the use of Push-IMAP
- **Read receipts**
- **Largest userbase** - recipients _not_ using Delta Chat can be reached as well
- **Compatible** - not only to itself
- **Elegant** and **simple** user interface
- **Distributed** system
- **No Spam** - only messages of known users are shown by default
- **Reliable** - safe for professional use
- **Trustworthy** - can even be used for business messages
- **Libre software** and [standards-based](https://delta.chat/en/standards)


API Documentation
--------------------------------------------------------------------------------

The C-API is documented at <https://deltachat.github.io/api/>.

Please keep in mind, that your derived work must be released under a
GPL-compatible licence.  For details, please have a look at the [LICENSE file](https://github.com/deltachat/deltachat-core/blob/master/LICENSE) accompanying the source code.


Build
--------------------------------------------------------------------------------

Delta Chat Core can be built as a library using the
[meson](http://mesonbuild.com) build system. It depends on a number
of external libraries, most of which are detected using
[pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/).
Usually this just works automatically, provided the depending libraries are
installed correctly.

By default a few stripped-down versions of these libraries are bundled
with Delta Chat Core and these will be used.  They are marked as
optional in the list below.  It is possible to use system-provided
versions of these libraries using a configure option to meson.

Otherwise installing all of these using your system libraries is the
easiest route.  Please note that you may need "development" packages
installed for these to work.

- [LibEtPan](https://github.com/dinhviethoa/libetpan); **optional** A
  stripped-down version of this library is vendored and used by
  default.  Use the `system-etpan=true` option to use a
  system-provided version instead.  Note that this does not use
  pkg-config so the system-provided version will be looked up by using
  `libetpan-config` which must be in the PATH.  Version 1.8 or newer
  is required.

- [OpenSSL](https://www.openssl.org/)

- [SQLite](https://sqlite.org/)

- [zlib](https://zlib.net)

- libsasl

- [bzip2](http://bzip.org)

To build you need to have [meson](http://mesonbuild.com) (at least version 0.36.0) and
[ninja](https://ninja-build.org) installed as well.

On Linux (e.g. Debian Stretch) you can install all these using:

`sudo apt install libetpan-dev libssl-dev libsqlite3-dev libsasl2-dev libbz2-dev zlib1g-dev meson ninja-build`.

Once all dependencies are installed, creating a build is as follows,
starting from the project's root directory:

```
mkdir builddir
cd builddir
meson
# Optionally configure some other parameters
# run `meson configure` to see the options, e.g.
#    meson configure -Dsystem-etpan=true
ninja
sudo ninja install
sudo ldconfig
```

The install keeps a log of which files were installed. Uninstalling
is thus also supported:
```
sudo ninja uninstall
```

Note that the above assumes `/usr/local/lib` is configured somewhere
in `/etc/ld.so.conf` or `/etc/ld.so.conf.d/*`, which is fairly
standard.  It is possible your system uses
`/usr/local/lib/x86_64-linux-gnu` which should be auto-detected and
just work as well.


License
--------------------------------------------------------------------------------

Licensed under the GPLv3, see LICENSE file for details.

Copyright © 2017, 2018 Delta Chat contributors
