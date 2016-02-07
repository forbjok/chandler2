module chandl.utils.htmlutils;

import std.file : read, readText;
import std.utf : UTFException;

const(char)[] readHTML(in string filename) {

    const(char)[] html;
    try {
        html = readText(filename);
    }
    catch (UTFException) {
        // If file is not valid UTF-8, read it raw
        html = cast(char[])read(filename);
    }

    return html;
}
