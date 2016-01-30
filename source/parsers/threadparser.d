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
    IThread parseThread(in string url, in char[] html);
}

class UpdateResult {
    string[] newLinks;

    this(string[] newLinks) {
        this.newLinks = newLinks;
    }
}
