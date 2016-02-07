module chandl.utils.rfc822datetime;

import std.conv : text;
import std.datetime;
import std.string : rightJustify;

enum rfc822months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
enum rfc822days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

@safe pure S zeroPad(S)(in S s, in size_t width) {
    return rightJustify(s, width, '0');
}

string toRFC822DateTime(in SysTime time) {
    // Build date string
    auto dateString =
        rfc822days[time.dayOfWeek]
        ~ ", "
        ~ text(time.day).zeroPad(2)
        ~ " "
        ~ rfc822months[time.month - 1]
        ~ " "
        ~ text(time.year);

    // Build timezone string
    string timeZoneString;
    if (time.timezone == UTC()) {
        timeZoneString = "GMT";
    }
    else {
        auto offset = time.utcOffset();
        auto splitOffset = offset.split!("hours", "minutes");

        auto factor = offset.total!("minutes") < 0 ? -1 : 1;

        timeZoneString =
            (factor > 0 ? '+' : '-')
            ~ text(splitOffset.hours * factor).zeroPad(2)
            ~ text(splitOffset.minutes * factor).zeroPad(2);
    }

    // Build time string (including the timezone)
    auto timeString =
        text(time.hour).zeroPad(2)
        ~ ":"
        ~ text(time.minute).zeroPad(2)
        ~ ":"
        ~ text(time.second).zeroPad(2)
        ~ " "
        ~ timeZoneString;

    return dateString ~ " " ~ timeString;
}

unittest {
    import dunit.toolkit;
    import std.typecons;

    auto times = [
        tuple("Sat, 06 Feb 2016 08:00:00 GMT", SysTime(DateTime(2016, 2, 6, 8, 0, 0), UTC())),
        tuple("Sat, 06 Feb 2016 08:00:00 +0200", SysTime(DateTime(2016, 2, 6, 8, 0, 0), new immutable SimpleTimeZone(120.minutes))),
        tuple("Sat, 06 Feb 2016 08:00:00 -0130", SysTime(DateTime(2016, 2, 6, 8, 0, 0), new immutable SimpleTimeZone(-90.minutes)))
    ];

    foreach (t; times) {
        auto rfc822string = t[0];
        auto time = t[1];

        auto stringifiedTime = toRFC822DateTime(time);
        stringifiedTime.assertEqual(rfc822string);

        auto parsedTime = parseRFC822DateTime(stringifiedTime);
        parsedTime.assertEqual(time);
    }
}
