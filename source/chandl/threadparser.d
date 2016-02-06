module chandl.threadparser;

interface IThread {
    const(char)[] getHtml();
    ILink[] getLinks();

    UpdateResult update(in char[] newHtml);
}

interface ILink {
    @property string tag();
    @property string attr();
    @property string url();
    @property string url(in string value);
}

interface IThreadParser {
    IThread parseThread(in char[] html);
}

struct UpdateResult {
    int[] newPosts;
    ILink[] newLinks;
}
