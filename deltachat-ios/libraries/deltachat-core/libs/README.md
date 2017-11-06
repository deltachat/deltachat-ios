This directory contains some libraries needed by the Delta Chat core library.

While it is also possible, to use the corresponding system libraries, it may
be easier on some OS to use the source from here which compiles fine under
"normal" circumstances.

Moreover, using the libraries from this directory may make fixing errors easier
(as we use the same code under different Delta Chat implementations).  The
disadvantage to the system libraries may be that the system may react faster
on security fixes than Delta Chat - I think this is true only for Linux.  For
the same reason, packages using non-sytem libraries may be rejected from some
Linux repositories.

Moreover, we've fixed some bugs here and there; these lines are marked by
`EDIT BY MR` then (as soon as we find the time, we should check if such changes
could form a pull request to the used library).
