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

const(char)[] purgeScripts(in const(char)[] html) {
    import html : createDocument, Node;

    // Parse HTML
    auto document = createDocument(html);

    /* Instead of destroying elements directly while iterating, we store them all
       in an array and destroy them afterwards.

       This is done because destroying them during iteration causes a segfault
       in newer versions of "htmld". (0.3.1+) */

    Node[] nodesToDestroy;

    foreach(e; document.querySelectorAll("script", document.root)) {
        nodesToDestroy ~= e;
    }

    foreach(e; nodesToDestroy) {
        e.destroy();
    }

    return document.root.html;
}
