This directory contains the sources for a little CLI test program.

These files are not needed when using Delta Chat Core as a library.

The CLI program is compiled to `\<builddir\>/cmdline/delta`.

Upon start, a test routine is executed (`stress_functions` from `stress.c`).
To speed up the start `stress_functions(mailbox);` can be commented out in `main.c` before compilation.
