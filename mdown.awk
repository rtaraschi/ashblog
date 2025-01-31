#-------------------!/usr/bin/env busybox
#
# Markdown processor in AWK. It is simplified from d.awk
# https://github.com/wernsey/d.awk
#
# (c) 2016 Werner Stoop
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

BEGIN {

    # Configuration options
    if(Title=="") Title = "Documentation";
    if(Theme=="") Theme = 1;
    if(Pretty=="") Pretty = 0;
    if(HideToCLevel=="") HideToCLevel = 3;
    #TopLinks = 1;
    #classic_underscore = 1;
    if(MaxWidth=="") MaxWidth="1080px";

    Mode = "p";
    ToC = ""; ToCLevel = 1;
    for(i = 0; i < 128; i++)
        _ord[sprintf("%c", i)] = i;
    srand();
}

{gsub(/\r/,"");}

{
    Out = Out filter($0);
}

END {

    if(Mode == "ul" || Mode == "ol") {
        while(ListLevel > 1)
            Buf = Buf "\n</" Open[ListLevel--] ">";
        Out = Out tag(Mode, Buf "\n");
    } else if(Mode == "pre") {
        while(ListLevel > 1)
            Buf = Buf "\n</" Open[ListLevel--] ">";
        Out = Out tag(Mode, Buf "\n");
    } else {
        Buf = trim(scrub(Buf));
        if(Buf)
            Out = Out tag(Mode, Buf);
    }

    if(Out) {
        #Out = fix_footnotes(Out);
        #Out = fix_links(Out);
        #Out = fix_abbrs(Out);
        #Out = make_toc(Out);

        print trim(Out);
        if(footnotes) {
            footnotes = fix_links(footnotes);
            print "<hr><ol class=\"footnotes\">\n" footnotes "</ol>";
        }
    }
}

function escape(st) {
    gsub(/&/, "\\&amp;", st);
    gsub(/</, "\\&lt;", st);
    gsub(/>/, "\\&gt;", st);
    return st;
}
function strip_tags(st) {
    gsub(/<\/?[^>]+>/,"",st);
    return st;
}
function trim(st) {
    sub(/^[[:space:]]+/, "", st);
    sub(/[[:space:]]+$/, "", st);
    return st;
}
function filter(st,       res,tmp, linkdesc, url, delim, edelim, name, def) {
    if(Mode == "p") {
        if(match(st, /^[[:space:]]*\[[-._[:alnum:][:space:]]+\]:/)) {
            linkdesc = ""; LastLink = 0;
            match(st,/\[.*\]/);
            LinkRef = tolower(substr(st, RSTART+1, RLENGTH-2));
            st = substr(st, RSTART+RLENGTH+2);
            match(st, /[^[:space:]]+/);
            url = substr(st, RSTART, RLENGTH);
            st = substr(st, RSTART+RLENGTH+1);
            if(match(url, /^<.*>/))
                url = substr(url, RSTART+1, RLENGTH-2);
            if(match(st, /["'(]/)) {
                delim = substr(st, RSTART, 1);
                edelim = (delim == "(") ? ")" : delim;
                if(match(st, delim ".*" edelim))
                    linkdesc = substr(st, RSTART+1, RLENGTH-2);
            }
            LinkUrls[LinkRef] = escape(url);
            if(!linkdesc) LastLink = 1;
            LinkDescs[LinkRef] = escape(linkdesc);
            return;
        } else if(LastLink && match(st, /^[[:space:]]*["'(]/)) {
            match(st, /["'(]/);
            delim = substr(st, RSTART, 1);
            edelim = (delim == "(") ? ")" : delim;
            st = substr(st, RSTART);
            if(match(st, delim ".*" edelim))
                LinkDescs[LinkRef] = escape(substr(st,RSTART+1,RLENGTH-2));
            LastLink = 0;
            return;
        } else if(match(st, /^[[:space:]]*\[\^[-._[:alnum:][:space:]]+\]:[[:space:]]*/)) {
            match(st, /\[\^[[:alnum:]]+\]:/);
            name = substr(st, RSTART+2,RLENGTH-4);
            def = substr(st, RSTART+RLENGTH+1);
            Footnote[tolower(name)] = scrub(def);
            return;
        } else if(match(st, /^[[:space:]]*\*\[[[:alnum:]]+\]:[[:space:]]*/)) {
            match(st, /\[[[:alnum:]]+\]/);
            name = substr(st, RSTART+1,RLENGTH-2);
            def = substr(st, RSTART+RLENGTH+2);
            Abbrs[toupper(name)] = def;
            return;
        } else if(match(st, /^((    )| *\t)/) || match(st, /^[[:space:]]*```+[[:alnum:]]*/)) {
            Preterm = trim(substr(st, RSTART,RLENGTH));
            st = substr(st, RSTART+RLENGTH);
            if(Buf) res = tag("p", scrub(Buf));
            Buf = st;
            push("pre");
        } else if(!trim(Prev) && match(st, /^[[:space:]]*[*-][[:space:]]*[*-][[:space:]]*[*-][-*[:space:]]*$/)) {
            if(Buf) res = tag("p", scrub(Buf));
            Buf = "";
            res = res "<hr>\n";
        } else if(match(st, /^[[:space:]]*===+[[:space:]]*$/)) {
            Buf = trim(substr(Buf, 1, length(Buf) - length(Prev) - 1));
            if(Buf) res= tag("p", scrub(Buf));
            if(Prev) res = res heading(1, scrub(Prev));
            Buf = "";
        } else if(match(st, /^[[:space:]]*---+[[:space:]]*$/)) {
            Buf = trim(substr(Buf, 1, length(Buf) - length(Prev) - 1));
            if(Buf) res = tag("p", scrub(Buf));
            if(Prev) res = res heading(2, scrub(Prev));
            Buf = "";
        } else if(match(st, /^[[:space:]]*#+/)) {
            sub(/#+[[:space:]]*$/, "", st);
            match(st, /#+/);
            ListLevel = RLENGTH;
            tmp = substr(st, RSTART+RLENGTH);
            if(Buf) res = tag("p", scrub(Buf));
            res = res heading(ListLevel, scrub(trim(tmp)));
            Buf = "";
        } else if(match(st, /^[[:space:]]*>/)) {
            if(Buf) res = tag("p", scrub(Buf));
            Buf = scrub(trim(substr(st, RSTART+RLENGTH)));
            push("blockquote");
        } else if(match(st, /^[[:space:]]*([*+-]|[[:digit:]]+\.)[[:space:]]/)) {
            if(Buf) res = tag("p", scrub(Buf));
            Buf="";
            match(st, /^[[:space:]]*/);
            ListLevel = 1;
            indent[ListLevel] = RLENGTH;
            Open[ListLevel]=match(st, /^[[:space:]]*[*+-][[:space:]]*/)?"ul":"ol";
            push(Open[ListLevel]);
            res = res filter(st);
        } else if(match(st, /^[[:space:]]*$/)) {
            if(trim(Buf)) {
                res = tag("p", scrub(trim(Buf)));
                Buf = "";
            }
        } else
            Buf = Buf st "\n";
        LastLink = 0;
    } else if(Mode == "blockquote") {
        if(match(st, /^[[:space:]]*>[[:space:]]*$/))
            Buf = Buf "\n</p><p>";
        else if(match(st, /^[[:space:]]*>/))
            Buf = Buf "\n" scrub(trim(substr(st, RSTART+RLENGTH)));
        else if(match(st, /^[[:space:]]*$/)) {
            res = tag("blockquote", tag("p", trim(Buf)));
            pop();
            res = res filter(st);
        } else
            Buf = Buf st;
    } else if(Mode == "pre") {
        if(!Preterm && match(st, /^((    )| *\t)/) || Preterm && !match(st, /^[[:space:]]*```+/))
            Buf = Buf ((Buf)?"\n":"") substr(st, RSTART+RLENGTH);
        else {
            gsub(/\t/,"    ",Buf);
            if(length(trim(Buf)) > 0) {
                Lang = "";
                if(match(Preterm, /^[[:space:]]*```+/)) {
                    Lang = trim(substr(Preterm, RSTART+RLENGTH));
                    if(Lang) {
                        Lang = "class=\"prettyprint lang-" Lang "\"";
                        HasCode=1;
                    }
                }
                res = tag("pre", tag("code", escape(Buf), Lang));
            }
            pop();
            if(Preterm) sub(/^[[:space:]]*```+[[:alnum:]]*/,"",st);
            res = res filter(st);
        }
    } else if(Mode == "ul" || Mode == "ol") {
        if(ListLevel == 0 || match(st, /^[[:space:]]*$/) && (RLENGTH <= indent[1])) {
            while(ListLevel > 1)
                Buf = Buf "\n</" Open[ListLevel--] ">";
            res = tag(Mode, "\n" Buf "\n");
            pop();
        } else {
            if(match(st, /^[[:space:]]*([*+-]|[[:digit:]]+\.)/)) {
                tmp = substr(st, RLENGTH+1);
                match(st, /^[[:space:]]*/);
                if(RLENGTH > indent[ListLevel]) {
                    indent[++ListLevel] = RLENGTH;
                    if(match(st, /^[[:space:]]*[*+-]/))
                        Open[ListLevel] = "ul";
                    else
                        Open[ListLevel] = "ol";
                    Buf = Buf "\n<" Open[ListLevel] ">";
                } else while(RLENGTH < indent[ListLevel])
                    Buf = Buf "\n</" Open[ListLevel--] ">";
                if(match(tmp,/^[[:space:]]*\[[xX[:space:]]\]/)) {
                    st = substr(tmp,RLENGTH+1);
                    tmp = tolower(substr(tmp,RSTART,RLENGTH));
                    Buf = Buf "<li><input type=\"checkbox\" " (index(tmp,"x")?"checked":"") " disabled>" scrub(st);
                } else
                    Buf = Buf "<li>" scrub(tmp);
            } else if(match(st, /^[[:space:]]*$/)){
                Buf = Buf "<br>\n";
            } else {
                sub(/^[[:space:]]+/,"",st);
                Buf = Buf "\n" scrub(st);
            }
        }
    }
    Prev = st;
    return res;
}
function scrub(st,    mp, ms, me, r, p, tg, a) {
    sub(/  $/,"<br>\n",st);
    gsub(/(  |[[:space:]]+\\)\n/,"<br>\n",st);
    gsub(/(  |[[:space:]]+\\)$/,"<br>\n",st);
    while(match(st, /(__?|\*\*?|~~|`+|[&><\\])/)) {
        a = substr(st, 1, RSTART-1);
        mp = substr(st, RSTART, RLENGTH);
        ms = substr(st, RSTART-1,1);
        me = substr(st, RSTART+RLENGTH, 1);
        p = RSTART+RLENGTH;

        if(!classic_underscore && match(mp,/_+/)) {
            if(match(ms,/[[:alnum:]]/) && match(me,/[[:alnum:]]/)) {
                tg = substr(st, 1, index(st, mp));
                r = r tg;
                st = substr(st, index(st, mp) + 1);
                continue;
            }
        }
        st = substr(st, p);
        r = r a;
        ms = "";

        if(mp == "\\") {
            if(match(st, /^!?\[/)) {
                r = r "\\" substr(st, RSTART, RLENGTH);
                st = substr(st, 2);
            } else if(match(st, /^(\*\*|__|~~|`+)/)) {
                r = r substr(st, 1, RLENGTH);
                st = substr(st, RLENGTH+1);
            } else {
                r = r substr(st, 1, 1);
                st = substr(st, 2);
            }
            continue;
        } else if(mp == "_" || mp == "*") {
            if(match(me,/[[:space:]]/)) {
                r = r mp;
                continue;
            }
            p = index(st, mp);
            while(p && match(substr(st, p-1, 1),/[\\[:space:]]/)) {
                ms = ms substr(st, 1, p-1) mp;
                st = substr(st, p + length(mp));
                p = index(st, mp);
            }
            if(!p) {
                r = r mp ms;
                continue;
            }
            ms = ms substr(st,1,p-1);
            r = r itag("em", scrub(ms));
            st = substr(st,p+length(mp));
        } else if(mp == "__" || mp == "**") {
            if(match(me,/[[:space:]]/)) {
                r = r mp;
                continue;
            }
            p = index(st, mp);
            while(p && match(substr(st, p-1, 1),/[\\[:space:]]/)) {
                ms = ms substr(st, 1, p-1) mp;
                st = substr(st, p + length(mp));
                p = index(st, mp);
            }
            if(!p) {
                r = r mp ms;
                continue;
            }
            ms = ms substr(st,1,p-1);
            r = r itag("strong", scrub(ms));
            st = substr(st,p+length(mp));
        } else if(mp == "~~") {
            p = index(st, mp);
            if(!p) {
                r = r mp;
                continue;
            }
            while(p && substr(st, p-1, 1) == "\\") {
                ms = ms substr(st, 1, p-1) mp;
                st = substr(st, p + length(mp));
                p = index(st, mp);
            }
            ms = ms substr(st,1,p-1);
            r = r itag("del", scrub(ms));
            st = substr(st,p+length(mp));
        } else if(match(mp, /`+/)) {
            p = index(st, mp);
            if(!p) {
                r = r mp;
                continue;
            }
            ms = substr(st,1,p-1);
            r = r itag("code", escape(ms));
            st = substr(st,p+length(mp));
        } else if(mp == ">") {
            r = r "&gt;";
        } else if(mp == "<") {

            p = index(st, ">");
            if(!p) {
                r = r "&lt;";
                continue;
            }
            tg = substr(st, 1, p - 1);
            if(match(tg,/^[[:alpha:]]+[[:space:]]/)) {
                a = substr(tg,RSTART+RLENGTH-1);
                tg = substr(tg,1,RLENGTH-1);
            } else
                a = "";

            if(match(tolower(tg), "^/?(a|abbr|div|span|blockquote|pre|img|code|p|em|strong|sup|sub|del|ins|s|u|b|i|br|hr|ul|ol|li|table|thead|tfoot|tbody|tr|th|td|caption|column|col|colgroup|figure|figcaption|dl|dd|dt|mark|cite|q|var|samp|small|details|summary)$")) {
                r = r "<" tg a ">";
            } else if(match(tg, "^[[:alpha:]]+://[[:graph:]]+$")) {
                if(!a) a = tg;
                r = r "<a href=\"" tg "\">" a "</a>";
            } else if(match(tg, "^[[:graph:]]+@[[:graph:]]+$")) {
                if(!a) a = tg;
                r = r "<a href=\"" obfuscate("mailto:" tg) "\">" obfuscate(a) "</a>";
            } else {
                r = r "&lt;";
                continue;
            }

            st = substr(st, p + 1);
        } else if(mp == "&") {
            if(match(st, /^[#[:alnum:]]+;/)) {
                r = r "&" substr(st, 1, RLENGTH);
                st = substr(st, RLENGTH+1);
            } else {
                r = r "&amp;";
            }
        }
    }
    return r st;
}

function push(newmode) {Stack[StackTop++] = Mode; Mode = newmode;}
function pop() {Mode = Stack[--StackTop];Buf = ""; return Mode;}
function heading(level, st,       res, href) {
    st = trim(st);
    if(level > 6) level = 6;
    href = tolower(st);
    href = strip_tags(href);
    gsub(/[^ [:alnum:]]+/, "", href);
    gsub(/ +/, "-", href);
    if(!LinkUrls[href]) LinkUrls[href] = "#" href;
    if(!LinkUrls[tolower(st)]) LinkUrls[tolower(st)] = "#" href;
    res = tag("h" level, st (TopLinks?"&nbsp;&nbsp;<a class=\"top\" title=\"Return to top\" href=\"#\">&#8593;&nbsp;Top</a>":""), "id=\"" href "\"");
    for(;ToCLevel < level; ToCLevel++) {
        ToC_ID++;
        if(ToCLevel < HideToCLevel) {
            ToC = ToC "<a class=\"toc-button\" id=\"toc-btn-" ToC_ID "\" onclick=\"toggle_toc_ul('" ToC_ID "')\">&#x25B2;</a>";
            ToC = ToC "<ul class=\"toc-" ToCLevel "\" id=\"toc-ul-" ToC_ID "\">";
        } else {
            ToC = ToC "<a class=\"toc-button\" id=\"toc-btn-" ToC_ID "\" onclick=\"toggle_toc_ul('" ToC_ID "')\">&#x25BC;</a>";
            ToC = ToC "<ul style=\"display:none;\" class=\"toc-" ToCLevel "\" id=\"toc-ul-" ToC_ID "\">";
        }
    }
    for(;ToCLevel > level; ToCLevel--)
        ToC = ToC "</ul>";
    ToC = ToC "<li class=\"toc-" level "\"><a class=\"toc-" level "\" href=\"#" href "\">" st "</a>\n";
    ToCLevel = level;
    return res;
}
function make_toc(st,              r,p,dis,t,n) {
    if(!ToC) return st;
    for(;ToCLevel > 1;ToCLevel--)
        ToC = ToC "</ul>";
    p = match(st, /!\[toc[-+]?\]/);
    while(p) {
        if(substr(st,RSTART-1,1) == "\\") {
            r = r substr(st,1,RSTART-2) substr(st,RSTART,RLENGTH);
            st = substr(st,RSTART+RLENGTH);
            p = match(st, /!\[toc[-+]?\]/);
            continue;
        }

        ++n;
        dis = index(substr(st,RSTART,RLENGTH),"+");
        t = "<div>\n<a id=\"toc-button-" n "\" class=\"toc-button\" onclick=\"toggle_toc(" n ")\"><span id=\"btn-text-" n "\">" (dis?"&#x25B2;":"&#x25BC;") "</span>&nbsp;Contents</a>\n" \
            "<div id=\"table-of-contents-" n "\" style=\"display:" (dis?"block":"none") ";\">\n<ul class=\"toc-1\">" ToC "</ul>\n</div>\n</div>";
        r = r substr(st,1,RSTART-1);
        r = r t;
        st = substr(st,RSTART+RLENGTH);
        p = match(st, /!\[toc[-+]?\]/);
    }
    return r st;
}
function fix_links(st,          lt,ld,lr,url,img,res,rx,pos,pre) {
    do {
        pre = match(st, /<pre>/); # Don't substitute in <pre> blocks
        pos = match(st, /\[[^\]]+\]/);
        if(!pos)break;
        if(pre && pre < pos) {
            pre = match(st, /<\/pre>/);
            res = res substr(st,1,RSTART+RLENGTH);
            st = substr(st, RSTART+RLENGTH);
            continue;
        }
        img=substr(st,RSTART-1,1)=="!";
        if(substr(st, RSTART-(img?2:1),1)=="\\") {
            res = res substr(st,1,RSTART-(img?3:2));
            if(img && substr(st,RSTART,RLENGTH)=="[toc]")res=res "\\";
            res = res substr(st,RSTART-(img?1:0),RLENGTH+(img?1:0));
            st = substr(st, RSTART + RLENGTH);
            continue;
        }
        res = res substr(st, 1, RSTART-(img?2:1));
        rx = substr(st, RSTART, RLENGTH);
        st = substr(st, RSTART+RLENGTH);
        if(match(st, /^[[:space:]]*\([^)]+\)/)) {
            lt = substr(rx, 2, length(rx) - 2);
            match(st, /\([^)]+\)/);
            url = substr(st, RSTART+1, RLENGTH-2);
            st = substr(st, RSTART+RLENGTH);
            ld = "";
            if(match(url,/[[:space:]]+["']/)) {
                ld = url;
                url = substr(url, 1, RSTART - 1);
                match(ld,/["']/);
                delim = substr(ld, RSTART, 1);
                if(match(ld,delim ".*" delim))
                    ld = substr(ld, RSTART+1, RLENGTH-2);
            }  else ld = "";
            if(img)
                res = res "<img src=\"" url "\" title=\"" ld "\" alt=\"" lt "\">";
            else
                res = res "<a href=\"" url "\" title=\"" ld "\">" lt "</a>";
        } else if(match(st, /^[[:space:]]*\[[^\]]*\]/)) {
            lt = substr(rx, 2, length(rx) - 2);
            match(st, /\[[^\]]*\]/);
            lr = trim(tolower(substr(st, RSTART+1, RLENGTH-2)));
            if(!lr) {
                lr = tolower(trim(lt));
                if(LinkDescs[lr]) lt = LinkDescs[lr];
            }
            st = substr(st, RSTART+RLENGTH);
            url = LinkUrls[lr];
            ld = LinkDescs[lr];
            if(img)
                res = res "<img src=\"" url "\" title=\"" ld "\" alt=\"" lt "\">";
            else
                res = res "<a href=\"" url "\" title=\"" ld "\">" lt "</a>";
        } else
            res = res (img?"!":"") rx;
    } while(pos > 0);
    return res st;
}
function fix_footnotes(st,         r,p,n,i,d,fn,fc) {
    p = match(st, /\[\^[^\]]+\]/);
    while(p) {
        if(substr(st,RSTART-2,1) == "\\") {
            r = r substr(st,1,RSTART-3) substr(st,RSTART,RLENGTH);
            st = substr(st,RSTART+RLENGTH);
            p = match(st, /\[\^[^\]]+\]/);
            continue;
        }
        r = r substr(st,1,RSTART-1);
        d = substr(st,RSTART+2,RLENGTH-3);
        n = tolower(d);
        st = substr(st,RSTART+RLENGTH);
        if(Footnote[tolower(n)]) {
            if(!fn[n]) fn[n] = ++fc;
            d = Footnote[n];
        } else {
            Footnote[n] = scrub(d);
            if(!fn[n]) fn[n] = ++fc;
        }
        footname[fc] = n;
        d = strip_tags(d);
        if(length(d) > 20) d = substr(d,1,20) "&hellip;";
        r = r "<sup title=\"" d "\"><a href=\"#footnote-" fn[n] "\" id=\"footnote-pos-" fn[n] "\" class=\"footnote\">[" fn[n] "]</a></sup>";
        p = match(st, /\[\^[^\]]+\]/);
    }
    for(i=1;i<=fc;i++)
        footnotes = footnotes "<li id=\"footnote-" i "\">" Footnote[footname[i]] \
            "<a title=\"Return to Document\" class=\"footnote-back\" href=\"#footnote-pos-" i \
            "\">&nbsp;&nbsp;&#8630;&nbsp;Back</a></li>\n";
    return r st;
}
function fix_abbrs(str,         st,k,r,p) {
    for(k in Abbrs) {
        r = "";
        st = str;
        t = escape(Abbrs[toupper(k)]);
        gsub(/&/,"\\&", t);
        p = match(st,"[^[:alnum:]]" k "[^[:alnum:]]");
        while(p) {
            r = r substr(st, 1, RSTART);
            r = r "<abbr title=\"" t "\">" k "</abbr>";
            st = substr(st, RSTART+RLENGTH-1);
            p = match(st,"[^[:alnum:]]" k "[^[:alnum:]]");
        }
        str = r st;
    }
    return str;
}
function tag(t, body, attr) {
    if(attr)
        attr = " " trim(attr);
    # https://www.w3.org/TR/html5/grouping-content.html#the-p-element
    if(t == "p" && (match(body, /<\/?(div|table|blockquote|dl|ol|ul|h[[:digit:]]|hr|pre)[>[:space:]]/))|| (match(body,/!\[toc\]/) && substr(body, RSTART-1,1) != "\\"))
        return "<" t attr ">" body "\n";
    else
        return "<" t attr ">" body "</" t ">\n";
}
function itag(t, body) {
    return "<" t ">" body "</" t ">";
}
function obfuscate(e,     r,i,t,o) {
    for(i = 1; i <= length(e); i++) {
        t = substr(e,i,1);
        r = int(rand() * 100);
        if(r > 50)
            o = o sprintf("&#x%02X;", _ord[t]);
        else if(r > 10)
            o = o sprintf("&#%d;", _ord[t]);
        else
            o = o t;
    }
    return o;
}
