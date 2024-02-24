module google_api.utils;

@safe:

///
inout(char)[ ] validateUtf(return scope inout(ubyte)[ ] data) pure {
    import std.utf: validate;

    inout result = cast(inout(char)[ ])data;
    result.validate();
    return result;
}
