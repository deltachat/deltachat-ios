import deltachat
from deltachat import capi


def test_empty_context():
    ctx = capi.lib.dc_context_new(capi.ffi.NULL, capi.ffi.NULL, capi.ffi.NULL)
    capi.lib.dc_close(ctx)


def test_cb(register_dc_callback):
    def cb(ctx, evt, data1, data2):
        return 0
    ctx = capi.lib.dc_context_new(capi.lib.py_dc_callback,
                                  capi.ffi.NULL, capi.ffi.NULL)
    register_dc_callback(ctx, cb)
    capi.lib.dc_close(ctx)
    assert deltachat._DC_CALLBACK_MAP[ctx] is cb
