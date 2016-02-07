module chandl.parsers;

import chandl.threadparser;

package {
    IThreadParser[string] parsers;
}

void registerParser(in string name, IThreadParser parser) {
    parsers[name] = parser;
}

IThreadParser getParser(in string name) {
    if (name !in parsers) {
        throw new ParserNotFoundException(name);
    }

    return parsers[name];
}

class ParserNotFoundException : Exception {
    this(in string name) {
        super("Parser not found: " ~ name);
    }
}
