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
