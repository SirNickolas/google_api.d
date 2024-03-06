module google_api.d.attributes;

///
public import vibe.data.serialization: byName, embedNullable, name, optional;

///
enum base64Encoded;

/// TODO: Use a dedicated type rather than a UDA.
enum date;

/// TODO: Use a dedicated type rather than a UDA.
enum dateTime;

/// TODO: Use a dedicated type rather than a UDA.
enum duration;

///
enum fieldMask;

///
struct minimum {
    int value; ///
}

///
struct maximum {
    int value; ///
}

///
struct pattern {
    string value; ///
}

///
enum readOnly;
