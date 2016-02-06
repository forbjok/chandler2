module chandl.parsers;

import chandl.threadparser;

package {
    IThreadParser[string] parsers;
}

void registerParser(in string name, IThreadParser parser) {
    parsers[name] = parser;
}

IThreadParser getParser(in string name) {
    if (name in parsers) {
        return parsers[name];
    }

    return null;
}
