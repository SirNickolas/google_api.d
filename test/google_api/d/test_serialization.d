module google_api.d.test_serialization;

import std.typecons: Nullable, Ternary, nullable;
import vibe.data.json: Json;
import google_api.d.serialization;

@safe:

alias thisModule = google_api.d.test_serialization;

enum Dir { n, e, s, w }

immutable string[4] enumMemberNames = ["n", "e", "s", "w"];

struct Point {
    long x, y;
}

bool serializeAsJson(scope ref Buffer b, scope ref const Point p) /+pure+/ => '{'
    .add(b, `"x":`, p.x)
    .add(b, `"y":`, p.y)
    .finish(b);

/+pure+/ unittest {
    auto b = createBuffer(64);
    const j = Json(null);
    const n = nullable(3);
    const Point coords = { -64, 83 };
    immutable numbers = [[0uL, 1], [2uL, 3]];
    const ok = '{'
        .addB(b, `"light":false`, true)
        .add(b, `"key":`, "Example")
        .add(b, `"numbers":`, numbers)
        .add(b, `"json":`, j)
        .add(b, `"dict":`, ["prop": [12L]])
        .add(b, `"double":`, 1.23)
        .add(b, `"integer":`, n)
        .add(b, `"ulong":`, 0uL, 1uL)
        .add(b, `"flag":`, Ternary.no)
        .add!thisModule(b, `"points":`, [coords])
        .add!thisModule(b, `"compass":`, [["n": Dir.n], ["e": Dir.e], ["s": Dir.s], ["w": Dir.w]])
        .finish(b);
    assert(ok);
    () @trusted {
        assert(b[ ] ==
            `{"light":false,"key":"Example","numbers":[["0","1"],["2","3"]],"json":null,` ~
            `"dict":{"prop":["12"]},"double":1.23,"integer":3,"ulong":"0","flag":false,` ~
            `"points":[{"x":"-64","y":"83"}],"compass":[{"n":"n"},{"e":"e"},{"s":"s"},{"w":"w"}]}`
        );
    }();
}

/+pure+/ unittest {
    auto b = createBuffer(4);
    Json j;
    Nullable!string ns;
    Point p;
    const ok = '{'
        .addB(b, `"success":true`, false)
        .add(b, `"t":`, Ternary.unknown)
        .add(b, `"j":`, j)
        .add(b, `"ns":`, ns)
        .add(b, `"s":`, "")
        .add(b, `"a":`, (string[string][ ]).init)
        .add(b, `"aa":`, (int[string]).init)
        .add!thisModule(b, `"d":`, Dir.n)
        .add!thisModule(b, `"p":`, p)
        .finish(b);
    assert(!ok);
    () @trusted {
        assert(b[ ] == "{}");
    }();
}

nothrow pure @nogc unittest {
    Buffer b;
    bool flag;
    static assert(!__traits(compiles, '{'.add(b, `"b":`, flag))); // Should call `addB` instead.
}
