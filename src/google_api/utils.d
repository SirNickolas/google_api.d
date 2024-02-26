module google_api.utils;

@safe:

///
pragma(inline, true)
@property auto delegate_(alias func)() nothrow pure @nogc {
    static struct S {
        static if (is(typeof(func) P == __parameters) || is(typeof(*func) P == __parameters))
            auto ref f(P args) scope {
                return func(args);
            }
        else
            static assert(false, "`", func, "` must not have untyped parameters");
    }

    return &(S*).init.f;
}

///
inout(char)[ ] validateUtf(return scope inout(ubyte)[ ] data) pure {
    import std.utf: validate;

    inout result = cast(inout(char)[ ])data;
    result.validate();
    return result;
}

///
char[ ] concat(Args...)(scope const Args args) nothrow pure {
    import std.array: uninitializedArray;
    import std.conv: toChars;

    enum extra = {
        size_t n;
        static foreach (T; Args)
            static if (is(T == char))
                n++;
            else static if (is(T == ubyte))
                n += 3;
            else static if (is(T == byte))
                n += 4;
            else static if (is(T == ushort) || is(T == bool))
                n += 5;
            else static if (is(T == short))
                n += 6;
            else static if (is(T == uint))
                n += 10;
            else static if (is(T == int))
                n += 11;
            else static if (is(T == ulong) || is(T == long))
                n += 20;
            else
                static assert(is(immutable T == immutable char[ ]), "Invalid type `", T, "`");
        return n;
    }();
    size_t i = extra;
    static foreach (j, T; Args)
        static if (is(immutable T == immutable char[ ]))
            i += args[j].length;

    auto result = uninitializedArray!(char[ ])(i);
    i = 0;
    static foreach (arg; args)
        static if (is(immutable typeof(arg) == immutable char[ ]))
            result[i .. i += arg.length] = arg;
        else static if (is(typeof(arg) == const char))
            result[i++] = arg;
        else static if (is(typeof(arg) == const bool))
            if (arg)
                result[i .. i += 4] = "true";
            else
                result[i .. i += 5] = "false";
        else {{
            static if (arg.sizeof < 4) {
                static if (__traits(isUnsigned, arg))
                    uint arg = arg;
                else
                    int arg = arg;
            }
            foreach (c; arg.toChars)
                result[i++] = c;
        }}

    return result[0 .. i];
}
