module google_api.test;

import google_api.http;
import google_api.utils;

@safe:

//
// google_api.utils:
//

pure unittest {
    import std.exception: assertThrown;
    import std.utf: UTFException;

    const data = "test";
    assert(validateUtf(cast(immutable(ubyte)[ ])data) is data);
    assert(validateUtf(null) is null);

    assertThrown!UTFException(validateUtf([0x80]));
}
