Delta Chat Core Library
================================================================================

You can use the _Delta Chat Core Library_ to build **your own messenger** or
plugin, that is completely **compatible** to the existing email infrastructure.

![Logo](https://delta.chat/assets/features/start-img4.png)

The library is used eg. in the [Delta Chat Android Frontend](https://github.com/deltachat/deltachat-android).

Using this library in your app, you get the **ease** of well-known messengers
with the **reach** of e-mail. Moreover, you're **independent** from other companies or
services - as your data is not relayed to Delta Chat, you won't even add new
dependencies here.

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


Coding
--------------------------------------------------------------------------------

If you are a developer and have an idea for another crazy chat, social or messaging
app you are encouraged to take this source code as a base. We would love to see
_many_ different messengers out there, based on existing, distributed
infrastructure. But we hate to see the user's data hidden on some companies
servers with undefined backgrounds.

Some hints:

- Regard the header files in the `src`-directory as a documentation;
  `mrmailbox.h` is a good starting point

- Headers may cointain headlines as "library-private" - stull following there
  is not meant to be used by the library user.

- Two underscores at the end of a function-name may be a _hint_, that this
  function does no resource locking.

- For objects, C-structures are used.  If not mentioned otherwise, you can
  read the members here directly.

- For `get`-functions, you have to unref the return value in some way.

- Strings in function arguments or return values are usually UTF-8 encoded

- Threads are implemented using POSIX threads (pthread_* functions)

- For indentation, use tabs.  Alignments that are not placed at the beginning
  of a line should be done with spaces.

- For padding between functions, classes etc. use 2 empty lines

- Source files are encoded as UTF-8 with Unix line endings (a simple `LF`, `0x0A` or
  `\n`)

Please keep in mind, that your derived work must be released under a
GPL-compatible licence.  For details, please have a look at the [LICENSE file](https://github.com/deltachat/deltachat-core/blob/master/LICENSE) accompanying the source code.

---

Copyright © 2017 Delta Chat contributors
