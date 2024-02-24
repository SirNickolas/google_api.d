module google_api.extras.vibe_http;

///
public import google_api.http;

@safe:

///
nothrow pure @nogc unittest {
    import google_api.auth.service_account: TokenManagerConfig;

    scope client = new VibeHttpClient;
    TokenManagerConfig cfg = {
        client: client,
    };
}

///
class VibeHttpClient: IHttpClient {
    import vibe.http.client: HTTPClientRequest;

    ///
    protected immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params,
        scope void delegate(scope HTTPClientRequest) @safe requester,
    ) scope @trusted {
        import vibe.http.client: HTTPMethod, requestHTTP;
        import vibe.stream.operations: readAll;

        immutable(ubyte)[ ] result;

        // We need `@trusted` all over the place because `vibe-http` disregards `scope`.
        requestHTTP(params.url, (scope req) @trusted {
            final switch (params.method) {
                case HttpMethod.get:  req.method = HTTPMethod.GET;  break;
                case HttpMethod.post: req.method = HTTPMethod.POST; break;
            }
            req.contentType = params.contentType;
            requester(req);
        }, (scope res) @trusted {
            res.readRawBody((scope InputStream stream) @trusted {
                result = cast(immutable)stream.readAll();
            });
        });

        return result;
    }

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope InputStream data,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope InputStream data, ulong length,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data, length); });
    }

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope const(ubyte)[ ] data,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }
}
