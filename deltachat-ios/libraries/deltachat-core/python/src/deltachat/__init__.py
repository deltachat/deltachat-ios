from deltachat import capi


_DC_CALLBACK_MAP = {}


@capi.ffi.def_extern()
def py_dc_callback(ctx, evt, data1, data2):
    """The global event handler.

    CFFI only allows us to set one global event handler, so this one
    looks up the correct event handler for the given context.
    """
    return _DC_CALLBACK_MAP.get(ctx, lambda *a: 0)
