import pytest

import deltachat


@pytest.fixture
def register_dc_callback(monkeypatch):
    """Register a callback for a given context.

    This is a function-scoped fixture and the function will be
    unregisterd automatically on fixture teardown.
    """
    def register_dc_callback(ctx, func):
        monkeypatch.setitem(deltachat._DC_CALLBACK_MAP, ctx, func)
    return register_dc_callback
