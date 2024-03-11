module google_api.d.buffer;

public import std.range.primitives: put; ///

@safe:

///
struct Buffer {
nothrow pure:
    import std.array: Appender;

    /++
        An opaque type used by `mark`/`reset` API. Resetting to `Buffer.Mark.init` is guaranteed
        to be equivalent to `clear`.
    +/
    struct Mark { private size_t _m; }

    /++
        An output range of characters and strings. Do not assume it has any particular type or
        supports any other operation besides `put` (which should be invoked
        [as a free function](https://dlang.org/phobos/std_range_primitives.html#put), not via UFCS).
    +/
    Appender!(char[ ]) sink;

    @disable this(this);

    ///
    ref Buffer opOpAssign(string op: "~")(char c) scope return {
        sink ~= c;
        return this;
    }

    /// ditto
    ref Buffer opOpAssign(string op: "~")(scope const(char)[ ] s) scope return {
        sink ~= s;
        return this;
    }

    /++
        Retrieve data accumulated in the buffer. Calls to `put` and `reserve` might invalidate
        the returned slice, making its pointer dangling.
    +/
    inout(char)[ ] opIndex() scope inout @system @nogc => sink[ ];

    /++
        Return a newly allocated string holding this buffer’s contents.
    +/
    char[ ] dupData() scope const => sink[ ].dup;

    ///
    @property size_t capacity() scope const @nogc => sink.capacity;

    ///
    void reserve(size_t size) scope { sink.reserve(size); }

    /++
        Clear the buffer without deallocating its storage.
    +/
    void clear() scope @nogc { sink.clear(); }

    /++
        Make a checkpoint, which the buffer can later be reset to.
    +/
    @property Mark mark() scope const @nogc => Mark(sink[ ].length);

    /++
        Discard data written since the specified _mark without reallocating the storage. It is
        forbidden to _reset to a _mark after resetting to an earlier _mark (or clearing the buffer).
    +/
    void reset(Mark mark) scope {
        try
            sink.shrinkTo(mark._m);
        catch (Exception e)
            assert(false, e.msg);
    }

    /++
        `Buffer` is non-copyable; use this method explicitly when you need it. The returned copy’s
        contents will match this buffer’s one, although capacity might differ.
    +/
    @property Buffer dup() scope const {
        import std.array: appender;

        return Buffer(appender(dupData()));
    }
}

/// ditto
Buffer createBuffer(size_t initialSize) nothrow pure {
    import std.array: appender, uninitializedArray;

    auto app = appender(uninitializedArray!(char[ ])(initialSize));
    app.clear();
    return Buffer(app);
}
