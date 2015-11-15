" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    559


if !exists('g:enabler#dirs')
    " A list of directories where plugins are stored.
    " Any bundle in one of these directories can be enabled via 
    " |:Enable|.
    "
    " See also |g:enabler#auto#dirs| for support for |:Autoenabler|.
    let g:enabler#dirs = split(globpath(&rtp, 'bundle'), '\n')   "{{{2
endif


if !exists('g:enabler#ftbundle_dirs')
    " A list of directories that contain filetype bundles. A ftbundle is 
    " a subdirectory with the name of a filetype. All bundles in this 
    " subdirectory will be enabled when editing a file with the given 
    " filetype for the first time.
    "
    " |:Enablegenerate| will scan ftbundles for |ftdetect| files in 
    " order to make its |:autocmd|s available for |:Autoenabler|. If 
    " your ftbundles don't include a ftdetect file, it might be 
    " necessary to keep the bundle in |g:enabler#auto#dirs| or to make 
    " sure an appropriate autocmd is executed on startup.
    let g:enabler#ftbundle_dirs = split(globpath(&rtp, 'ftbundle'), '\n')   "{{{2
endif


if !exists('g:enabler#exclude_rx')
    " Sub-directories matching this |regexp| will be excluded.
    let g:enabler#exclude_rx = '^[._]'   "{{{2
endif


if !exists('g:enabler#exclude_dirs')
    " Sub-directories in |g:enabler#dirs| that should be excluded.
    let g:enabler#exclude_dirs = ['bundle']   "{{{2
endif


if !exists('g:enabler#rtp_pos')
    " Insert new dirs at this position in 'runtimepath'.
    " Corresponding "after" directories will always be added at the last 
    " position.
    "
    " CAUTION: This variable must be set before the first invocation.
    let g:enabler#rtp_pos = 1   "{{{2
endif


if !exists('g:enabler#config_dir')
    " The directory for configuration files.
    " If empty, configuration files will be searched in 'runtimepath'.
    " Configuration files will (normally) be loaded only once. They are 
    " meant to help users to keep their |vimrc| file small.
    let g:enabler#config_dir = ''   "{{{2
endif


if !exists('g:enabler#debug')
    " :nodoc:
    let g:enabler#debug = 0   "{{{2
endif


let s:rtp_pos = g:enabler#rtp_pos
let s:autoloads = {}
let s:ftplugins = {}
let s:dependencies = {}
let s:undefine = {}
let s:onload = {}
let s:loaded = {}
let s:filepatterns = {}


" :nodoc:
function! enabler#Update() "{{{3
    let items = split(globpath(join(g:enabler#dirs, ','), '*'), '\n')
    let items = filter(items, 'isdirectory(v:val)')
    let s:dirs = {}
    for dname in items
        let plugin = fnamemodify(dname, ':t')
        if plugin !~ g:enabler#exclude_rx && index(g:enabler#exclude_dirs, plugin) == -1
            let s:dirs[plugin] = dname
        endif
    endfor
endf


function! s:IsLoaded(plugin) "{{{3
    return has_key(s:loaded, a:plugin)
endf


" Define a list of dependencies for a plugin.
"
" Examples:
"   call enabler#Dependency('vikitasks_vim', ['viki_vim'])
function! enabler#Dependency(plugin, dependencies) "{{{3
    " echom "DBG enabler#Dependency" a:plugin s:IsLoaded(a:plugin) string(a:dependencies)
    if !s:IsLoaded(a:plugin)
        let s:dependencies[a:plugin] = get(s:dependencies, a:plugin, []) + a:dependencies
        call s:AddUndefine(a:plugin, printf('call s:Remove(s:dependencies, %s)', string(a:plugin)))
    endif
endf


" Define a vim command to be executed after enabling a plugin.
function! enabler#Onload(plugin, exec) "{{{3
    if has_key(s:onload, a:plugin)
        call add(s:onload[a:plugin], a:exec)
    else
        let s:onload[a:plugin] = [a:exec]
    endif
endf


function! s:Dirs() "{{{3
    if !exists('s:dirs')
        call enabler#Update()
    endif
    return s:dirs
endf


" :nodoc:
function! enabler#Complete(lead, line, col) "{{{3
    return join(keys(s:Dirs()), "\n")
endf


" :display: enabler#Plugin(plugins, ?load_now=0, ?[subdir_rxs], ?rtp=split(&rtp, ','))
" If load_now == 1, load the vim files right away.
function! enabler#Plugin(plugins, ...) "{{{3
    let fname_rxs = ['[\/]_enabler.vim$', '[\/]plugin[\/].\{-}\.vim$']
    let load_now = a:0 >= 1 && a:1 >= 1 ? a:1 : !has('vim_starting')
    if a:0 >= 2
        let fname_rxs += a:2
    endif
    let rtp = a:0 >= 3 ? a:3 : split(&rtp, ',')
    " echom "DBG enabler#Plugin" string(a:plugins) load_now string(fname_rxs)
    let dirs = s:Dirs()
    let files = []
    let load_plugins = []
    for plugin in a:plugins
        if !has_key(dirs, plugin)
            echoerr "Enabler: Unknown plugin:" plugin
        elseif s:IsLoaded(plugin)
            continue
        else
            let s:loaded[plugin] = 1
            if has_key(s:dependencies, plugin)
                let rtp = enabler#Plugin(s:dependencies[plugin], load_now, [], rtp)
            endif
            let dir = dirs[plugin]
            let ndir = len(dir) + len('/')
            if index(rtp, dir) == -1
                let rtp = insert(rtp, dir, s:rtp_pos)
                let s:rtp_pos += 1
                if has_key(s:undefine, plugin)
                    for undef in s:undefine[plugin]
                        if g:enabler#debug
                            " echom "DBG undef" undef
                            exec undef
                        else
                            silent! exec undef
                        endif
                    endfor
                    call remove(s:undefine, plugin)
                endif
                let adir = dir .'/after'
                if isdirectory(adir)
                    let rtp = insert(rtp, adir, -1)
                endif
                if load_now == 1
                    " echom "DBG glob dir" dir
                    let vimfiles = split(glob(dir .'/plugin/**/*.vim'), '\n')
                    " echom "DBG vimfiles" string(vimfiles)
                    for fname_rx in fname_rxs
                        let sfiles = filter(copy(vimfiles), 'v:val =~# fname_rx')
                        let sfiles = map(sfiles, 'strpart(v:val, ndir)')
                        " echom "DBG sfiles" string(sfiles)
                        let files += sfiles
                    endfor
                endif
                call add(load_plugins, plugin)
            endif
        endif
    endfor
    let &rtp = join(rtp, ',')
    for plugin in load_plugins
        call s:LoadConfig('bundle/'. plugin)
    endfor
    if load_now
        for file in files
            try
                " unsilent echom 'DBG runtime!' file
                " echom "DBG" 'runtime!' fnameescape(file)
                exec 'runtime!' fnameescape(file)
            catch
                echohl ErrorMsg
                unsilent echom v:exception
                unsilent echom v:throwpoint
                echohl NONE
            endtry
        endfor
    endif
    for plugin in a:plugins
        if has_key(s:onload, plugin)
            for e in s:onload[plugin]
                " echom "DBG exec" e
                exec e
            endfor
        endif
    endfor
    return rtp
endf


function! s:Remove(dict, key) "{{{3
    if has_key(a:dict, a:key)
        call remove(a:dict, a:key)
    endif
endf


function! s:RemovePlugin(dict, key, ftplugin) "{{{3
    if has_key(a:dict, a:key)
        let ftps = a:dict[a:key]
        let i = index(ftps, a:ftplugin)
        if i >= 0
            call remove(ftps, i)
        endif
        if empty(ftps)
            call remove(a:dict, a:key)
        else
            let a:dict[a:key] = ftps
        endif
    endif
endf


let s:loaded_config = {}

function! s:LoadConfig(name) "{{{3
    " echom "DBG LoadConfig name" a:name
    if !has_key(s:loaded_config, a:name)
        if !empty(g:enabler#config_dir)
            let cfg = g:enabler#config_dir .'/'. a:name .'.vim'
            " echom "DBG LoadConfig config_file" cfg filereadable(cfg)
            if filereadable(cfg)
                exec 'source' fnameescape(cfg)
            endif
        else
            " echom "DBG LoadConfig enabler" a:name
            exec 'runtime! enabler/'. fnameescape(a:name) .'.vim'
        endif
        let s:loaded_config[a:name] = 1
    endif
endf


function! s:AddUndefine(plugin, undef) "{{{3
    if empty(a:plugin)
        echoerr string(a:plugins) a:undef
    endif
    if !has_key(s:undefine, a:plugin)
        let s:undefine[a:plugin] = [a:undef]
    else
        call add(s:undefine[a:plugin], a:undef)
    endif
endf


function! enabler#Autoload(rx, ...) "{{{3
    let ps = filter(copy(a:000), '!s:IsLoaded(v:val)')
    if !empty(ps)
        let s:autoloads[a:rx] = get(s:autoloads, a:rx, []) + ps
        for p in ps
            call s:AddUndefine(p, printf('call s:RemovePlugin(s:autoloads, %s, %s)', string(a:rx), string(p)))
        endfor
    endif
endf


" :display: enabler#Ftplugin(ft, PLUGINS...) or enabler#Ftplugin(ft, [PLUGINS])
function! enabler#Ftplugin(ft, ...) "{{{3
    if type(a:1) == 3
        let ps = a:1
    else
        let ps = a:000
    endif
    let ps = filter(copy(ps), '!s:IsLoaded(v:val)')
    if !empty(ps)
        let s:ftplugins[a:ft] = get(s:ftplugins, a:ft, []) + ps
        for p in ps
            call s:AddUndefine(p, printf('call s:RemovePlugin(s:ftplugins, %s, %s)', string(a:ft), string(p)))
        endfor
    endif
endf


" :display: enabler#Commands(plugin, [CMD...])
function! enabler#Commands(plugin, commands) "{{{3
    if s:IsLoaded(a:plugin)
        return
    endif
    let args = []
    for cmd in a:commands
        if cmd =~ '^[<-]'
            call add(args, cmd)
        else
            call enabler#Command(a:plugin, args + [cmd])
        endif
    endfor
endf


" :display: enabler#Command(plugin, "CMD DEF", ?OPTIONS={}) or enabler#Command(plugin, ["CMD", "DEF"], ?OPTIONS={})
function! enabler#Command(plugin, cmddef, ...) "{{{3
    if s:IsLoaded(a:plugin)
        return
    endif
    let options = a:0 >= 1 ? a:1 : {}
    let cdef = type(a:cmddef) == 3 ? a:cmddef : split(a:1, '\s\+')
    let sdef = type(a:cmddef) == 3 ? join(a:cmddef) : a:cmddef
    let ndef = len(cdef)
    let cmd = cdef[-1]
    let rangetype = get(options, 'rangetype', '')
    if empty(rangetype) ? sdef =~ '\s-range[[:space:]=]' : rangetype == 'range'
        let range = '["<line1>", "<line2>"]'
    elseif empty(rangetype) ? sdef =~ '\s-count[[:space:]=]' : rangetype == 'count'
        let range = '["<count>"]'
    elseif rangetype == 'rangecount'
        let range = '[".", "+<count>"]'
    else
        let range = '[]'
    end
    try
        exec printf('command! -nargs=* -bang %s call s:EnableCommand(%s, %s, "<bang>", %s, <q-args>)',
                    \ sdef,
                    \ string(cmd),
                    \ string(a:plugin),
                    \ range
                    \ )
        call s:AddUndefine(a:plugin, ':if exists(":'. cmd .'") == 2 | delcommand '. cmd .' | endif')
    catch
        echohl Error
        unsilent echom "Enabler: Error when defining stub command:" sdef
        unsilent echom v:exception
        echohl NONE
    endtry
endf


function! s:EnableCommand(cmd, plugin, bang, range, args) "{{{3
    " echom "DBG EnableCommand" a:cmd a:plugin
    call enabler#Plugin([a:plugin])
    let range = join(filter(copy(a:range), '!empty(v:val)'), ',')
    if exists(':'. a:cmd) == 2
        try
            exec range . a:cmd . a:bang .' '. a:args
        catch /^Vim\%((\a\+)\)\=:E481/
            exec a:cmd . a:bang .' '. a:args
        catch /^Vim\%((\a\+)\)\=:E121/
            " Ignore exception: was probably caused by a local variable 
            " that isn't visible in this context.
        catch
            echohl Error
            unsilent echom "Exception" v:exception "from" v:throwpoint
            unsilent echom v:errmsg
            echohl NONE
        endtry
    else
        echohl Error
        unsilent echom "Enabler: Unknown command:" a:cmd
        echohl NONE
    endif
endf


" Define a dummy map that will load PLUGIN upon first invocation.
" Examples:
"   call enabler#Map('tmarks_vim', '<silent> <f2> :TMarks<cr>')
function! enabler#Map(plugin, args) "{{{3
    " unsilent echom "DBG enabler#Map" string(a:args) a:plugin
    if s:IsLoaded(a:plugin)
        return
    endif
    let mcmd = 'map'
    let args = []
    let lhs = ''
    let rhs = ''
    let mode = 'cmd'
    let idx = 0
    let margs = type(a:args) == 3 ? a:args : split(a:args, ' \+')
    let nargs = len(margs)
    while idx < nargs
        let item = margs[idx]
        if mode == 'cmd'
            if item =~# '^.\?\(nore\)\?map$'
                let mcmd = item
            else
                let mode = 'args'
                continue
            endif
        elseif mode == 'args'
            if item =~# '^<\(buffer\|nowait\|silent\|special\|script\|expr\|unique\)>$'
                call add(args, item)
            else
                let mode = 'lhs'
                continue
            endif
        elseif mode == 'lhs'
            let lhs = item
            let mode = 'rhs'
        elseif mode == 'rhs'
            let rhs = join(margs[idx : -1])
            break
        endif
        let idx += 1
    endwh
    let sargs = join(args)
    let unmap = substitute(mcmd, '\(nore\)\?\zemap$', 'un', '')
    call s:AddUndefine(a:plugin, unmap .' '. lhs)
    if empty(rhs)
        let rhs1 = rhs
    else
        let undef = printf('%s %s %s %s', mcmd, sargs, lhs, rhs)
        call s:AddUndefine(a:plugin, undef)
        let rhs1 = substitute(rhs, '<', '<lt>', 'g')
    endif
    let lhs1 = substitute(lhs, '<', '<lt>', 'g')
    let [pre, post] = s:GetMapPrePost(mcmd)
    let cmd = printf('%s:call <SID>EnableMap(%s, %s, %s, %s, %s)<cr>%s',
                \ pre, string(mcmd), string(sargs), string(lhs1), string(a:plugin), string(rhs1), post)
    let map = [mcmd, sargs, lhs, cmd]
    exec join(map)
endf


function! s:GetMapPrePost(map) "{{{3
    let mode = matchstr(a:map, '\([incvoslx]\?\)\ze\(nore\)\?map')
    if mode ==# 'n'
        let pre  = ''
        let post = ''
    elseif mode ==# 'i'
        let pre = '<c-\><c-o>'
        let post = ''
    elseif mode ==# 'v' || mode ==# 'x'
        let pre = '<c-c>'
        let post = '<C-\><C-G>'
    elseif mode ==# 'c'
        let pre = '<c-c>'
        let post = '<C-\><C-G>'
    elseif mode ==# 'o'
        let pre = '<c-c>'
        let post = '<C-\><C-G>'
    else
        let pre  = ''
        let post = ''
    endif
    return [pre, post]
endf


function! s:EnableMap(mcmd, args, lhs, plugin, rhs) "{{{3
    " TLogVAR a:mcmd, a:args, a:lhs, a:plugin, a:rhs
    " let unmap = substitute(a:mcmd, '\(nore\)\?\zemap$', 'un', '')
    " " TLogVAR unmap, a:lhs
    " exec unmap a:lhs
    call enabler#Plugin([a:plugin])
    if !empty(a:rhs)
        exec a:mcmd a:args a:lhs a:rhs
    endif
    let lhs = a:lhs
    let ml = exists('g:mapleader') ? g:mapleader : '\'
    let lhs = substitute(lhs, '\c<leader>', escape(ml, '\'), 'g')
    if exists('g:maplocalleader')
        let lhs = substitute(lhs, '\c<localleader>', escape(g:maplocalleader, '\'), 'g')
    endif
    let lhs = substitute(lhs, '<\ze\w\+\(-\w\+\)*>', '\\<', 'g')
    let lhs = eval('"'. escape(lhs, '"') .'"')
    if a:mcmd =~ '^[vx]'
        let lhs = 'gv'. lhs
    elseif a:mcmd =~ '^[s]'
        let lhs = "<c-g>gv". lhs
    endif
    " TLogVAR lhs
    call feedkeys(lhs, 't')
endf


" :nodoc:
function! enabler#FuncUndefined(fn) "{{{3
    " echom "DBG enabler#FuncUndefined" a:fn
    let autoloads = filter(copy(s:autoloads), 'a:fn =~# v:key')
    let plugins = []
    for ps in values(autoloads)
        let plugins += ps
    endfor
    if !empty(plugins)
        " echom "DBG enabler#FuncUndefined" a:fn string(autoloads) string(plugins)
        call enabler#Plugin(plugins)
    endif
endf


" :nodoc:
function! enabler#AutoFiletype(ft) "{{{3
    " TLogVAR a:ft
    if !empty(g:enabler#ftbundle_dirs)
        let must_update = 0
        let ftdirs = split(globpath(join(g:enabler#ftbundle_dirs, ','), a:ft), '\n')
        " TLogVAR ftdirs
        let allftbundles = []
        for ftdir in ftdirs
            let ftbundles = split(globpath(ftdir, '*'), '\n')
            let ftbundles = filter(ftbundles, 'isdirectory(v:val)')
            let ftbundles = map(ftbundles, 'matchstr(v:val, ''[\/]\zs[^\/]\+$'')')
            let ftbundles = filter(ftbundles, '!empty(v:val)')
            if !empty(ftbundles)
                if index(g:enabler#dirs, ftdir) == -1
                    call add(g:enabler#dirs, ftdir)
                    let must_update = 1
                endif
                let allftbundles += ftbundles
            endif
        endfor
        if must_update
            call enabler#Update()
        endif
        if !empty(allftbundles)
            " TLogVAR allftbundles
            call enabler#Ftplugin(a:ft, allftbundles)
        endif
    endif
    call s:LoadConfig('ft/'. a:ft .'.vim')
    let ftplugins = get(s:ftplugins, a:ft, [])
    " echom "DBG enabler#AutoFiletype" a:ft string(ftplugins)
    if !empty(ftplugins)
        call enabler#Plugin(ftplugins, 1, [
                    \ '[\/]ftdetect[\/]'. a:ft .'[\/][^\/]\{-}\.vim$',
                    \ '[\/]ftplugin[\/]'. a:ft .'[\/][^\/]\{-}\.vim$',
                    \ '[\/]ftplugin[\/]'. a:ft .'_[^\/]\{-}\.vim$',
                    \ '[\/]indent[\/]'. a:ft .'[\/][^\/]\{-}\.vim$',
                    \ '[\/]indent[\/]'. a:ft .'_[^\/]\{-}\.vim$',
                    \ '[\/]syntax[\/]'. a:ft .'[\/][^\/]\{-}\.vim$',
                    \ '[\/]syntax[\/]'. a:ft .'_[^\/]\{-}\.vim$',
                    \ ])
    endif
endf


function! enabler#Filepattern(rx, ...) "{{{3
    let s:filepatterns[a:rx] = get(s:filepatterns, a:rx, []) + a:000
    for p in a:000
        call s:AddUndefine(p, printf('call s:RemovePlugin(s:filepatterns, %s, %s)', string(a:rx), string(p)))
    endfor
endf


function! enabler#Filetypepatterns(filename) "{{{3
    for rx in keys(s:filepatterns)
        if a:filename =~# rx
            let ps = s:filepatterns[rx]
            call enabler#Plugin(ps)
        endif
    endfor
endf


function! enabler#Autocmd(event, pattern, ...) abort "{{{3
    let cmd = printf('call s:EnableAutocmd(%s, expand("<amatch>"), %s)', string(a:event), string(a:000))
    exec 'autocmd Enabler' a:event a:pattern cmd
    exec 'autocmd Enabler' a:event a:pattern 'autocmd! Enabler' a:event a:pattern cmd
endf


function! s:EnableAutocmd(event, fname, plugins) abort "{{{3
    for plugin in a:plugins
        let ml = matchlist(plugin, '^\([^#]\+\)\%(#\(.*\)\)\?$')
        let [match, plugin1, group; rest] = ml
        call enabler#Plugin([plugin1], 1)
        exec 'doautocmd' group a:event a:fname
    endfor
endf

