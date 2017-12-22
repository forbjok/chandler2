module chandl.threadparser;

interface IThread {
    const(char)[] getHtml();
    ILink[] getLinks();

    UpdateResult update(in const(char)[] newHtml);
    bool isDead();
}

interface ILink {
    @property string tag();
    @property string attr();
    @property string url();
    @property string url(in string value);
}

interface IThreadParser {
    @property bool supportsUpdate();
    IThread parseThread(in const(char)[] html);
}

struct UpdateResult {
    ulong[] newPosts;
    ILink[] newLinks;
    bool isDead;
}

class ThreadParseException : Exception {
    this(string msg) {
        super("Error parsing thread: " ~ msg);
    }
}
