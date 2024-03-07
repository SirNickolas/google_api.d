module google_api.d.http;

///
public import vibe.core.stream: InputStream, RandomAccessStream;

@safe:

///
enum HttpMethod {
    get, ///
    put, ///
    post, ///
    patch, ///
    delete_, ///
}

///
struct HttpRequestParams {
    HttpMethod method; ///
    string url; ///
    string contentType; ///
}

///
interface IHttpClient {
    ///
    ubyte[ ] request(scope ref const HttpRequestParams, scope InputStream) scope;

    /// ditto
    ubyte[ ] request(scope ref const HttpRequestParams, scope InputStream, ulong length) scope;

    /// ditto
    ubyte[ ] request(scope ref const HttpRequestParams, scope const(ubyte)[ ]) scope;

    /// ditto
    final ubyte[ ] request(scope ref const HttpRequestParams params, scope RandomAccessStream data)
    scope @trusted {
        return request(params, data, data.size - data.tell());
    }
}

///
class HttpRequestException: Exception {
    ///
    int status;

    ///
    this(
        int status,
        string msg,
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable next = null,
    ) nothrow pure {
        import google_api.d.utils: concat;

        super(concat(status, ": ", msg), file, line, next);
        this.status = status;
    }
}

///
void enforceHttpStatus(int status, string msg, string file = __FILE__, size_t line = __LINE__)
pure {
    if (status < 200 || status >= 300)
        throw new HttpRequestException(status, msg, file, line);
}

///
struct GoogleHttpClient {
    import std.array: Appender;

    IHttpClient impl;
    Appender!(char[ ]) buffer;
}

///
GoogleHttpClient googleHttpClient(return scope IHttpClient impl) nothrow pure {
    import std.array: appender;

    auto app = appender!(char[ ]);
    app.reserve(512); // TODO: Select optimal size.
    return GoogleHttpClient(impl, app);
}
