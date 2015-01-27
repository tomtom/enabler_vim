" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    234


if !exists('g:enabler#auto#dirs')
    let g:enabler#auto#dirs = g:enabler#dirs   "{{{2
endif


if !exists('g:enabler#auto#kinds')
    " Define for what |enabler#auto#Generate()| generates stubs.
    " A dictionary with the following keys:
    "
    "   ftplugins (BOOLEAN) ... scan for ftplugins, syntax definitions, 
    "                           ftdetect files etc.
    "   plugin (see below) .... scan the "plugin" subdirectory
    "   autoload (see below) .. scan the "autoload" subdirectory
    "
    " Possible values for "plugin" & "autoload":
    "   d ... filetype detection/plugins
    "   c ... commands
    "   f ... functions, autoloads
    "   m ... maps
    let g:enabler#auto#kinds = {'ftplugins': 1, 'plugin': 'cf', 'autoload': 'f'}   "{{{2
endif


" :display: enabler#auto#Generate(?tagfiles=[GUESS])
" This will generate |g:enabler_autofile|. It will set up stub 
" definitions that will make bundles easily available.
"
" Only bundles saved under |g:enabler#auto#dirs| will be scanned.
"
" This will also add any enabler commands found in 
" `{g:enabler#config_dir}/{PLUGIN}.vim`.
function! enabler#auto#Generate(...) "{{{3
    if empty(g:enabler_autofile)
        echoerr "Enabler: Please set g:enabler_autofile first"
    else
        let vfiles = s:ListVimFiles()
        let fts = get(g:enabler#auto#kinds, 'ftplugins', 1) ? s:ScanFtplugins(vfiles) : []
        let enablers = {}
        let plugins = {}
        let progressbar = exists('g:loaded_tlib')
        if progressbar
            call tlib#progressbar#Init(len(vfiles), 'Enabler: Scanning %s', 20)
        else
            echo 'TPlugin: Scanning '. root .' ...'
        endif
        try
            let fidx = 0
            for [fullname, filename] in vfiles
                if progressbar
                    let fidx += 1
                    call tlib#progressbar#Display(fidx)
                endif
                " echom "DBG" filename
                if filename =~ '^[^\/]\+[\/]plugin[\/][^\/]\{-}\.vim$'
                    let kinds = get(g:enabler#auto#kinds, 'plugin', 'cf')
                elseif filename =~ '^[^\/]\+[\/]autoload[\/].\{-}\.vim$'
                    let kinds = get(g:enabler#auto#kinds, 'autoload', 'f')
                else
                    continue
                endif
                let plugin = s:GetBundleName(filename)
                if plugin !~ '^enabler\(_vim\)\?$'
                    let plugins[plugin] = 1
                    let le = len(enablers)
                    " TLogVAR filename, kinds, plugin
                    let enablers = s:ProcessFile(enablers, plugin, fullname, kinds)
                    " TLogVAR len(enablers)-le
                endif
            endfor
        finally
            if progressbar
                call tlib#progressbar#Restore()
            else
                redraw
            endif
        endtry
        let auto = keys(enablers)
        let auto = sort(auto)
        for plugin in keys(plugins)
            let pauto = g:enabler#config_dir .'/'. plugin .'.vim'
            if filereadable(pauto)
                let auto += readfile(pauto)
            endif
        endfor
        call writefile(fts + auto, g:enabler_autofile)
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


function! s:GetBundleName(filename) "{{{3
    let bundle = matchstr(a:filename, '[^\/]\+\ze[\/]\(plugin\|autoload\|ftplugin\|syntax\|indent\|ftdetect\)[\/].\{-}\.vim$')
    return bundle
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
                endif
            endif
        endif
    endfor
    let eft += map(items(fts), 'printf("call enabler#Ftplugin(%s, %s)", string(v:val[0]), string(keys(v:val[1])))')
    return eft
endf


function! s:ProcessFile(enablers, plugin, fullname, kinds) "{{{3
    " TLogVAR a:plugin, a:fullname, a:kinds
    let lines = split(substitute(join(readfile(a:fullname), "\n"), '\n\_s\+\\', '', 'g'), '\n')
    let enablers = a:enablers
    for line in lines
        if line !~ '\S' || line =~ '^\s*"'
            continue
        endif
        if stridx(a:kinds, 'm') != -1
            let enablers = s:ScanMap(a:plugin, a:enablers, line)
        endif
        if stridx(a:kinds, 'c') != -1
            let enablers = s:ScanCommand(a:plugin, a:enablers, line)
        endif
        if stridx(a:kinds, 'f') != -1
            let enablers = s:ScanFunction(a:plugin, a:enablers, line)
        endif
    endfor
    return enablers
endf


function! s:ScanMap(plugin, enablers, line) "{{{3
    let tag = matchstr(a:line, '^\s*\zs.\?\%(nore\)\?map\s\+\%(<\%(buffer\|nowait\|silent\|special\|script\|expr\|unique\)>\s\)\+\S\+')
    if !empty(tag)
        return s:Add(a:plugin, a:enablers, 1, ' '.tag, printf("call enabler#Map(%s, %s)", string(a:plugin), string(tag)))
    else
        return a:enablers
    endif
endf


function! s:ScanCommand(plugin, enablers, line) "{{{3
    let tag = matchstr(a:line, '^\s*com\%[mand]!\?\s\+\zs\%(\%(-\S\+\)\s\+\)*\S\+')
    " TLogVAR a:line, tag
    if !empty(tag)
        let args = split(tag, '\s\+')
        return s:Add(a:plugin, a:enablers, 1, ':'. tag, printf("call enabler#Command(%s, [%s])",
                    \ string(a:plugin),
                    \ join(map(args, 'string(v:val)'), ', ')
                    \ ))
    else
        return a:enablers
    endif
endf


function! s:ScanFunction(plugin, enablers, line) "{{{3
    let tag = matchlist(a:line, '^\s*fu\%[nction]!\?\s\+\zs\%(\(\w\+#\)\|\(\u\w\+\)\s*(\)')
    if !empty(tag)
        if !empty(tag[1])
            let rx = '\V\^'. tag[1]
            let warn = 0
        elseif !empty(tag[2])
            let rx = '\V\^'. tag[2] .'\$'
            let warn = 1
        else
            echoerr "Enabler: ScanFunction: Internal error:" a:line
        endif
        return s:Add(a:plugin, a:enablers, warn, '*'. rx, printf("call enabler#Autoload(%s, %s)", string(rx), string(a:plugin)))
    else
        return a:enablers
    endif
endf


function! s:Add(plugin, enablers, warn, id, line) "{{{3
    " TLogVAR a:warn, a:id, a:line
    if has_key(a:enablers, a:line)
        if a:warn && a:enablers[a:line] != a:plugin
            echohl WarningMsg
            echom "Autoenabler: Conflicting defintions for:" a:line
            echohl NONE
        endif
    else
        let a:enablers[a:line] = a:plugin
    endif
    return a:enablers
endf

