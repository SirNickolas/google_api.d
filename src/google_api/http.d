module google_api.http;

///
public import vibe.core.stream: InputStream, RandomAccessStream;

@safe:

///
enum HttpMethod {
    get, ///
    post, ///
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
    immutable(ubyte)[ ] request(scope ref const HttpRequestParams, scope InputStream) scope;

    /// ditto
    immutable(ubyte)[ ] request(scope ref const HttpRequestParams, scope InputStream, ulong length)
    scope;

    /// ditto
    immutable(ubyte)[ ] request(scope ref const HttpRequestParams, scope const(ubyte)[ ]) scope;

    /// ditto
    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope RandomAccessStream data,
    ) scope @trusted {
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
        import google_api.utils: concat;

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
