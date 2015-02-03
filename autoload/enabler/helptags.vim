" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    8


" :nodoc:
function! enabler#helptags#Generate() "{{{3
    echon 'Generating helptags (please wait) ... '
    redraw
    call s:MakeHelpTags(g:enabler#dirs, 'guess') 
    echo 'DONE!'
endf


function! s:MakeHelpTags(roots, master_dir) "{{{3
    let tagfiles = []
    for root in a:roots
        let helpdirs = split(glob(root .'/*/doc'), '\n')
        for doc in helpdirs
            " TLogVAR doc
            if isdirectory(doc) && !empty(glob(doc .'/*.*'))
                let tags = doc .'/tags'
                if !filereadable(tags) || s:ShouldMakeHelptags(doc)
                    let cmd = 'silent '
                    let cmd .= 'helptags '
                    let cmd .= fnameescape(doc)
                    try
                        exec cmd
                    catch /^Vim\%((\a\+)\)\=:E154/
                        echohl WarningMsg
                        echom "Enabler:" substitute(v:exception, '^Vim\%((\a\+)\)\=:E154:\s*', '', '')
                        echohl NONE
                    endtry
                endif
                if filereadable(tags)
                    call add(tagfiles, tags)
                endif
            endif
        endfor
    endfor
    if a:master_dir == 'guess'
        let master_dir = split(&rtp, ',')[0] .'/doc'
    else
        let master_dir = a:master_dir
    endif
    if isdirectory(master_dir) && !empty(tagfiles)
        exec 'silent! helptags '. fnameescape(master_dir)
        let master_tags = master_dir .'/tags'
        " TLogVAR master_dir, master_tags
        if filereadable(master_tags)
            let helptags = readfile(master_tags)
        else
            let helptags = []
        endif
        for tagfile in tagfiles
            let tagfiletags = readfile(tagfile)
            let dir = fnamemodify(tagfile, ':p:h')
            call map(tagfiletags, 's:ProcessHelpTags(v:val, dir)')
            let helptags += tagfiletags
        endfor
        call sort(helptags)
        call writefile(helptags, master_tags)
    endif
endf


function! s:ProcessHelpTags(line, dir) "{{{3
    let items = split(a:line, '\t')
    let items[1] = a:dir .'/'. items[1]
    return join(items, "\t")
endf


function! s:ShouldMakeHelptags(dir) "{{{3
    let tags = a:dir .'/tags'
    let timestamp = getftime(tags)
    let create = 0
    for file in split(glob(a:dir .'/*'), '\n')
        if getftime(file) > timestamp
            let create = 1
            break
        endif
    endfor
    return create
endf

