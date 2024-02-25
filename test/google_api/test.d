module google_api.test;

import google_api.http;
import google_api.utils;

@safe:

// google_api.utils.validateUtf:

pure unittest {
    import std.exception: assertThrown;
    import std.utf: UTFException;

    const data = "test";
    assert(validateUtf(cast(immutable(ubyte)[ ])data) is data);
    assert(validateUtf(null) is null);

    assertThrown!UTFException(validateUtf([0x80]));
}

// google_api.utils.concat:

nothrow pure unittest {
    immutable b = true;
    char[2] sep = ": ";
    string s =
        concat("test", ' ', b, sep[ ], ubyte(0), byte(1), ushort(2), short(3), 4u, 5, 6uL, 7L);
    assert(s == "test true: 01234567");

    assert(concat() == "");
    assert(concat(false) == "false");
    assert(concat(ubyte.max) == "255");
    assert(concat(ushort.max) == "65535");
    assert(concat(uint.max) == "4294967295");
    assert(concat(ulong.max) == "18446744073709551615");
    assert(concat(byte.min) == "-128");
    assert(concat(short.min) == "-32768");
    assert(concat(int.min) == "-2147483648");
    assert(concat(long.min) == "-9223372036854775808");

    static assert(!__traits(compiles, concat(2.5)));
    static assert(!__traits(compiles, concat(null)));
    static assert(!__traits(compiles, concat((char*).init)));
}
