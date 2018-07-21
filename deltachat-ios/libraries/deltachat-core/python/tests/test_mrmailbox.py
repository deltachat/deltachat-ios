import pathlib

import pytest

from deltachat import capi


def test_empty_context():
    ctx = capi.lib.dc_context_new(capi.ffi.NULL, capi.ffi.NULL, capi.ffi.NULL)
    capi.lib.dc_close(ctx)
