" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    139


if !exists('g:enabler#auto#dirs')
    let g:enabler#auto#dirs = g:enabler#dirs   "{{{2
endif


" :display: enabler#auto#Generate(?tagfiles=[GUESS])
" This will generate |g:enabler_autofile|. It will set up stub 
" definitions that will make bundles easily available.
"
" If no tagfiles are named, |g:enabler#auto#dirs| will be searched for 
" tags files.
function! enabler#auto#Generate(...) "{{{3
    if empty(g:enabler_autofile)
        echoerr "Enabler: Please set g:enabler_autofile first"
    else
        " Update only if tags_files has changed
        " -> requires tlib
        let tags = &l:tags
        let s:tagfiles = map(tagfiles(), 'fnamemodify(v:val, ":h")')
        let tags_files = a:0 >= 1 && !empty(a:1) ? a:1 : s:GuessTagsFiles()
        " TLogVAR tags_files
        if empty(tags_files)
            echoerr "Enabler: No tags files"
        else
            try
                let fts = s:ScanFtplugins(s:ListVimFiles())
                let &l:tags = join(tags_files, ',')
                let tlist = taglist('.')
                let tlist = filter(tlist, 'index(["m", "c", "f"], v:val.kind) != -1')
                " TLogVAR empty(tlist)
                " let fts = s:ProcessTagList('s:AutoFtplugins', tlist)
                let tlist = filter(tlist, 'v:val.filename =~ ''\<\(plugin\|autoload\|ftplugin\|syntax\|indent\|ftdetect\)[\/][^\/]\{-}.vim''')
                let fns = s:ProcessTagList('s:AutoFunctions', filter(copy(tlist), 'v:val.kind ==# "f"'))
                let tlist = filter(tlist, 'v:val.filename =~ ''\<\(plugin\)[\/][^\/]\{-}.vim''')
                let maps = s:ProcessTagList('s:AutoMaps', filter(copy(tlist), 'v:val.kind ==# "m"'))
                let cmds = s:ProcessTagList('s:AutoCommands', filter(copy(tlist), 'v:val.kind ==# "c"'))
                let auto = maps + cmds + fns + fts
                call writefile(auto, g:enabler_autofile)
            finally
                let &l:tags = tags
                unlet! s:tagfiles
            endtry
        endif
    endif
endf


function! s:GuessTagsFiles() "{{{3
    let dirs = join(g:enabler#auto#dirs, ',')
    let tfiles = split(globpath(dirs, 'tags'), '\n') + split(globpath(dirs, '*/tags'), '\n')
    return tfiles
endf


function! s:ListVimFiles() "{{{3
    let vfiles = []
    for dir in g:enabler#auto#dirs
        let ndir = strlen(dir .'/')
        let vfiles1 = split(globpath(dir, '**/*.vim'), '\n')
        let vfiles1 = map(vfiles1, '[v:val, strpart(v:val, ndir)]')
        let vfiles += vfiles1
    endfor
    return vfiles
endf


function! s:ProcessTagList(fn, tlist) "{{{3
    " TLogVAR a:fn
    let akeys = {}
    let alist = []
    let s:cache = {}
    try
        for tdef in a:tlist
            let id = tdef.kind . tdef.name
            if has_key(akeys, id)
                echohl WarningMsg
                echom "Autoenabler: Already defined:" string(tdef)
                echohl NONE
            else
                let plugin = s:GetBundleName(tdef.filename)
                if plugin !~ '^enabler\(_vim\)$'
                    let ecmd = call(a:fn, [plugin, tdef])
                    if !empty(ecmd)
                        " TLogVAR id, ecmd
                        let akeys[id] = 1
                        call add(alist, ecmd)
                    endif
                endif
            endif
        endfor
    finally
        unlet! s:cache
    endtry
    return alist
endf


function! s:GetBundleName(filename) "{{{3
    let bundle = matchstr(a:filename, '[^\/]\+\ze[\/]\(plugin\|autoload\|ftplugin\|syntax\|indent\|ftdetect\)[\/].\{-}\.vim$')
    return bundle
endf


function! s:AutoMaps(plugin, tdef) "{{{3
    let tag = matchstr(a:tdef.cmd, '^/\^\zs.\?\%(nore\)\?map\s\+\%(<\%(buffer\|nowait\|silent\|special\|script\|expr\|unique\)>\s\)\+\S\+')
    if !empty(tag)
        return printf("call enabler#Map(%s, [%s])", string(tag), string(a:plugin))
    else
        return ''
    endif
endf


function! s:AutoCommands(plugin, tdef) "{{{3
    let tag = matchstr(a:tdef.cmd, '^/\^\s*com\%[mand]!\?\s\+\zs\%(\%(-\S\+\)\s\+\)*\w\+')
    if !empty(tag)
        let args = split(tag, '\s\+')
        call add(args, a:plugin)
        return printf("call enabler#Command(%s)", join(map(args, 'string(v:val)'), ', '))
    else
        return ''
    endif
endf


function! s:AutoFunctions(plugin, tdef) "{{{3
    let tag = matchlist(a:tdef.cmd, '^/\^\s*fu\%[nction]!\?\s\+\zs\%(\(\w\+#\)\|\(\u\w\+\)\s*(\)')
    if !empty(tag)
        if !empty(tag[1])
            let rx = '\V\^'. tag[1]
            if has_key(s:cache, rx)
                return ''
            endif
        elseif !empty(tag[2])
            let rx = '\V\^'. tag[2] .'\$'
        else
            echoerr "Enabler: AutoFunctions: Internal error:" a:tdef.cmd
        endif
        let s:cache[rx] = 1
        return printf("call enabler#Autoload(%s, %s)", string(rx), string(a:plugin))
    else
        return ''
    endif
endf


function! s:ScanFtplugins(files) "{{{3
    let rx = '^[^\/]\+[\/]\%(indent\|ftplugin\|syntax\|ftdetect\)[\/]\%(\([^\/]\+\)[\/]\|\([^\/_.]\+\)\%(_[^\/.]\+\)\?\.vim\)'
    let fts = {}
    let eft = []
    for [fullname, filename] in a:files
        let m = matchlist(filename, rx)
        if !empty(m)
            let ft = m[1]
            if empty(ft)
                let ft = m[2]
            endif
            if !empty(ft)
                let plugin = s:GetBundleName(filename)
                if !has_key(fts, ft)
                    let fts[ft] = {}
                endif
                let fts[ft][plugin] = 1
                if filename =~ '^[^\/]\+[\/]ftdetect[\/]\%(\([^\/]\+\)[\/]\|\([^\/_.]\+\)\%(_[^\/.]\+\)\?\.vim\)'
                    let lines = readfile(fullname)
                    let lines = filter(lines, '!empty(v:val) && v:val !~ ''^\s*"''')
                    let eft += lines
                    " let pats = map(lines, 'matchstr(v:val, ''\<au\%[tocmd].\{-}\(BufNewFile|BufRead\)\s\+\zs\S\+'')')
                    " let pats = filter(pats, '!empty(v:val) && v:val !~ ''^\s*"''')
                    " for pat in pats
                    "     let enable = printf('automd Enabler BufNewFile,BufRead %s call enabler#Ftdetect(%s, %s)', ft, string(ft), string(plugin))
                    "     call add(eft, enable)
                    " endfor
                endif
            endif
        endif
    endfor
    let eft += map(items(fts), 'printf("call enabler#Ftplugin(%s, %s)", string(v:val[0]), string(keys(v:val[1])))')
    return eft
endf


function! s:AutoFtplugins(plugin, tdef) "{{{3
    let m = matchlist(a:tdef.filename, '[\/]\%(indent\|ftplugin\|syntax\|ftdetect\)[\/]\%(\([^\/]\+\)[\/]\|\([^\/_.]\+\)\%(_[^\/.]\+\)\?\.vim\)')
    if !empty(m)
        let ft = m[1]
        if empty(ft)
            let ft = m[2]
        endif
        if !empty(ft)
            let cid = ft .'_'. a:plugin
            if !has_key(s:cache, cid)
                let s:cache[cid] = 1
                return printf('call enabler#Ftplugin(%s, %s)', string(ft), string(a:plugin))
            endif
        endif
    endif
    return ''
endf

