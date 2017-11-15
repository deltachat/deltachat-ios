Delta Chat Core Library
================================================================================

You can use the _Delta Chat Core Library_ to build **your own messenger** or
plugin, that is completely **compatible** to the existing email infrastructure.

![Logo](https://delta.chat/assets/features/start-img4.png)

Using this library in your app, you get the **ease** of well-known messengers
with the **reach** of e-mail. Moreover, you're **independent** from other companies or
services - as your data is not relayed to Delta Chat, you won't even add new
dependencies here.

The library is used eg. in the [Delta Chat Android Frontend](https://github.com/deltachat/deltachat-android)
or in the [Delta Chat iOS Frontend](https://github.com/deltachat/deltachat-ios) but can also be used for
completely different messenger projects.

Some features at a glance

- **Secure** with automatic end-to-end-encryption, supporting the new
  [Autocrypt](https://autocrypt.readthedocs.io/en/latest/) standard
- **Fast** by the use of Push-IMAP
- **Read receipts**
- **Largest userbase** - receivers _not_ using Delta Chat can be reached as well
- **Compatible** - not only to itself
- **Elegant** and **simple** user interface
- **Distributed** system
- **No Spam** - only messages of known users are shown by default
- **Reliable** - safe for professional use
- **Trustworthy** - can even be used for business messages
- **Libre software** and [standards-based](https://delta.chat/en/standards)


API Documentation
--------------------------------------------------------------------------------

The C-API is documented at <https://deltachat.github.io/deltachat-core/html/>.

Please keep in mind, that your derived work must be released under a
GPL-compatible licence.  For details, please have a look at the [LICENSE file](https://github.com/deltachat/deltachat-core/blob/master/LICENSE) accompanying the source code.


Build
--------------------------------------------------------------------------------

The Delta Chat Core Library relies on the following external libs:

- [LibEtPan](https://github.com/dinhviethoa/libetpan), [OpenSSL](https://www.openssl.org/); for
  compilation, use eg. the following commands: `./autogen.sh; make;
  sudo make install prefix=/usr`
  To link against LibEtPan, add `libetpan-config --libs` in backticks to your
  project. This should also add the needed OpenSSL libraries.

- [SQLite](http://sqlite.org/) is available on most systems, however, you
  will also need the headers, please look for packages as `libsqlite3-dev`.
  To link against SQLite, add `-lsqlite3` to your project.

Alternatively, use the ready-to-use files from the libs-directory which are
suitable for common system.  You'll also find a fork of the needed Netpgp
library there.

---

Copyright © 2017 Delta Chat contributors
