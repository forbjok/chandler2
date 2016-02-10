module chandl.utils.htmlutils;

import std.conv : to;
import std.file : read, readText;
import std.utf : UTFException;

string readHTML(in string filename) {
    try {
        return readText(filename);
    }
    catch (UTFException) {
        // If file is not valid UTF-8, read it raw
        return read(filename).to!string;
    }
}
