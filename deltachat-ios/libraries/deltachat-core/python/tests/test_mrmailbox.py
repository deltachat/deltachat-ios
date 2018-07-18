import pathlib

import pytest

from deltachat import capi


@pytest.fixture
def tmppath(tmpdir):
    return pathlib.Path(tmpdir.strpath)


def test_new():
    mbox = capi.lib.mrmailbox_new(capi.ffi.NULL, capi.ffi.NULL, capi.ffi.NULL)
    capi.lib.mrmailbox_close(mbox)
    assert 0
