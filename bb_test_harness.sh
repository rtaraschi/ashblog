#!/usr/bin/env bash

set -o nounset

# print colored messages to STDERR on ANSI terminals
ghostprint()   { printf "\x1B[0;30m%s\x1B[0m\n" "$1" 1>&2; }
redprint()     { printf "\x1B[0;31m%s\x1B[0m\n" "$1" 1>&2; }
greenprint()   { printf "\x1B[0;32m%s\x1B[0m\n" "$1" 1>&2; }
yellowprint()  { printf "\x1B[0;33m%s\x1B[0m\n" "$1" 1>&2; }
blueprint()    { printf "\x1B[0;34m%s\x1B[0m\n" "$1" 1>&2; }
magentaprint() { printf "\x1B[0;35m%s\x1B[0m\n" "$1" 1>&2; }
cyanprint()    { printf "\x1B[0;36m%s\x1B[0m\n" "$1" 1>&2; }
whiteprint()   { printf "\x1B[0;37m%s\x1B[0m\n" "$1" 1>&2; }

# trim leading and trailing whitespace
trim() {
    sed -e "s/^[ \t]\+//" -e "s/[ \t]\+$//"
}

# Finds all tags referenced in one post.
# Accepts either filename as first argument, or post content at stdin
# Prints one line with space-separated tags to stdout
orig_tags_in_post() {
    sed -n "/^<p>$template_tags_line_header/{s/^<p>$template_tags_line_header//;s/<[^>]*>//g;s/[ ,]\+/ /g;p;}" "$1" | tr ', ' ' ' | trim
}

new_tags_in_post() {
    greenprint "NEW_TAGS_IN_POST($1)"
    sed -n "/^<p>$template_tags_line_header/{s/^<p>$template_tags_line_header//;s/<[^>]*>//g;s/[ ,]\+/\n/g;p;}" "$1" | awk 'length>1'
}

# Finds all posts referenced in a number of tags.
# Arguments are tags
# Prints one line with space-separated tags to stdout
orig_posts_with_tags() {
    greenprint "ORIG_POSTS_WITH_TAGS(NF=$#)"; for i; do greenprint ">>>$i<<<"; done
    (($# < 1)) && return
    set -- "${@/#/$prefix_tags}"
    set -- "${@/%/.html}"
    redprint "$# >>>$@<<<"
    for i; do yellowprint ">>>$i<<<"; done
    sed -n '/^<h3><a class="ablack" href="[^"]*">/{s/.*href="\([^"]*\)">.*/\1/;p;}' "$@" ### 2> /dev/null
}

new_posts_with_tags() {
    greenprint "NEW_POSTS_WITH_TAGS(NF=$#)"; for i; do greenprint ">>>$i<<<"; done
    [ $# -lt 1 ] && return
#   echo $# 1>&2
#   for i; do echo "    >>>$i<<<" 1>&2; done
#   sed -n '/^<h3><a class="ablack" href="[^"]*">/{s/.*href="\([^"]*\)">.*/\1/;p;}' "$@" | sort | uniq | tr '\n' ' ' | trim  # TODO 2> /dev/null
#    for tag; do
#        set == $@ $(echo "$tag" | sed -e "s/^/$prefix_tags/" -e "s/$/.html/")
#        shift 2    # don't ask me why this is 2 instead of 1, but it works
#    done
#   set -- $(echo "$@" | tr ' ' '\n' | sed -e "s/^/$prefix_tags/" -e "s/$/.html/" | tr '\n' ' ' | trim)
    postfiles=""
    for tag; do
        tagfile=$(echo "$tag" | sed -e "s/^/$prefix_tags/" -e "s/$/.html/")
        yellowprint ">>>$tag<<<--------->>>$tagfile<<<"
        postfile=$(sed -n '/^<h3><a class="ablack" href="[^"]*">/{s/.*href="\([^"]*\)">.*/\1/;p;}' "$tagfile") # TODO 2> /dev/null
        postfiles="${postfiles}${postfile}|"
    done
    { echo "$postfiles" | tr '|' '\n' | sort | uniq; } 1>&2
#   redprint "$# >>>$@<<<"
#   for i; do yellowprint ">>>$i<<<"; done
#   sed -n '/^<h3><a class="ablack" href="[^"]*">/{s/.*href="\([^"]*\)">.*/\1/;p;}' "$@" | sort | uniq | tr '\n' ' ' | trim  # TODO 2> /dev/null
}

# Rebuilds tag_*.html files
# if no arguments given, rebuilds all of them
# if arguments given, they should have this format:
# "FILE1 [FILE2 [...]]" "TAG1 [TAG2 [...]]"
# where FILEn are files with posts which should be used for rebuilding tags,
# and TAGn are names of tags which should be rebuilt.
# example:
# rebuild_tags "one_post.html another_article.html" "example-tag another-tag"
# mind the quotes!
orig_rebuild_tags() {
    if (($# < 2)); then
        # will process all files and tags
        files=$(ls -t ./*.html)
        all_tags=yes
    else
        # will process only given files and tags
        files=$(printf '%s\n' $1 | sort -u)
        files=$(ls -t $files)
        tags=$2
    fi
    echo -n "Rebuilding tag pages "
    n=0
    if [[ -n $all_tags ]]; then
        rm ./"$prefix_tags"*.html &> /dev/null
    else
        for i in $tags; do
            rm "./$prefix_tags$i.html" &> /dev/null
        done
    fi
    # First we will process all files and create temporal tag files
    # with just the content of the posts
    tmpfile=tmp.$RANDOM
    while [[ -f $tmpfile ]]; do tmpfile=tmp.$RANDOM; done
    while IFS='' read -r i; do
        is_boilerplate_file "$i" && continue;
        echo -n "."
        if [[ -n $cut_do ]]; then
            get_html_file_content 'entry' 'entry' 'cut' <"$i" | awk "/$cut_line/ { print \"<p class=\\\"readmore\\\"><a href=\\\"$i\\\">$template_read_more</a></p>\" ; next } 1"
        else
            get_html_file_content 'entry' 'entry' <"$i"
        fi >"$tmpfile"
        for tag in $(tags_in_post "$i"); do
            if [[ -n $all_tags || " $tags " == *" $tag "* ]]; then
                cat "$tmpfile" >> "$prefix_tags$tag".tmp.html
            fi
        done
    done <<< "$files"
    rm "$tmpfile"
    # Now generate the tag files with headers, footers, etc
    while IFS='' read -r i; do
        tagname=${i#./"$prefix_tags"}
        tagname=${tagname%.tmp.html}
        create_html_page "$i" "$prefix_tags$tagname.html" yes "$global_title &mdash; $template_tag_title \"$tagname\"" "$global_author"
        rm "$i"
    done < <(ls -t ./"$prefix_tags"*.tmp.html 2>/dev/null)
    echo
}

new_rebuild_tags() {
    if (($# < 2)); then
        # will process all files and tags
        files=$(ls -t ./*.html)
        all_tags=yes
    else
        # will process only given files and tags
        files=$(printf '%s\n' $1 | sort -u)
        files=$(ls -t $files)
        tags=$2
    fi
    echo -n "Rebuilding tag pages "
    n=0
    if [[ -n $all_tags ]]; then
        rm ./"$prefix_tags"*.html &> /dev/null
    else
        for i in $tags; do
            rm "./$prefix_tags$i.html" &> /dev/null
        done
    fi
    # First we will process all files and create temporal tag files
    # with just the content of the posts
    tmpfile=tmp.$RANDOM
    while [[ -f $tmpfile ]]; do tmpfile=tmp.$RANDOM; done
    while IFS='' read -r i; do
        is_boilerplate_file "$i" && continue;
        echo -n "."
        if [[ -n $cut_do ]]; then
            get_html_file_content 'entry' 'entry' 'cut' <"$i" | awk "/$cut_line/ { print \"<p class=\\\"readmore\\\"><a href=\\\"$i\\\">$template_read_more</a></p>\" ; next } 1"
        else
            get_html_file_content 'entry' 'entry' <"$i"
        fi >"$tmpfile"
        for tag in $(tags_in_post "$i"); do
            if [[ -n $all_tags || " $tags " == *" $tag "* ]]; then
                cat "$tmpfile" >> "$prefix_tags$tag".tmp.html
            fi
        done
    done <<< "$files"
    rm "$tmpfile"
    # Now generate the tag files with headers, footers, etc
    while IFS='' read -r i; do
        tagname=${i#./"$prefix_tags"}
        tagname=${tagname%.tmp.html}
        create_html_page "$i" "$prefix_tags$tagname.html" yes "$global_title &mdash; $template_tag_title \"$tagname\"" "$global_author"
        rm "$i"
    done < <(ls -t ./"$prefix_tags"*.tmp.html 2>/dev/null)
    echo
}

######################################################################

filename="title-on-this-line.html"
template_tags_line_header="Tags:"
prefix_tags="tag_"


orig_main() {
    echo "Posted $filename"
    orig_tags_in_post $filename
    relevant_tags=$(orig_tags_in_post $filename)
    echo "tags ${#relevant_tags} --->$relevant_tags<---"
    if [[ -n $relevant_tags ]]; then
        orig_posts_with_tags "$relevant_tags"
        #relevant_posts="$(orig_posts_with_tags $relevant_tags) $filename"
        #echo "    posts $# --->$relevant_posts"
        #orig_rebuild_tags "$relevant_posts" "$relevant_tags"
    fi
}

new_main() {
    echo "Posted $filename"
    new_tags_in_post "$filename"
    relevant_tags=$(new_tags_in_post "$filename")
    echo "tags ${#relevant_tags} --->$relevant_tags<---"
    if [ -n "$relevant_tags" ]; then
        new_posts_with_tags $relevant_tags     # do not quote $relevant_tags
        #relevant_posts=$(new_posts_with_tags "$relevant_tags") "$filename"
        #echo "    posts $# --->$relevant_posts"
        #new_rebuild_tags "$relevant_posts" "$relevant_tags"
    fi
}

orig_main

echo; echo
redprint "----------------------------------------------------------------------"
echo; echo

new_main
