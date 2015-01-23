" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    393


if !exists('g:enabler#dirs')
    " A list of directories where plugins are stored.
    let g:enabler#dirs = split(globpath(&rtp, 'bundle'), '\n')   "{{{2
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
    let g:enabler#debug = 0   "{{{2
endif


let s:rtp_pos = g:enabler#rtp_pos
let s:autoloads = {}
let s:ftplugins = {}
let s:dependencies = {}
let s:undefine = {}
let s:onload = {}
let s:loaded = {}


function! enabler#Update() "{{{3
    let items = split(globpath(join(g:enabler#dirs, ','), '*'), '\n')
    let items = filter(items, 'isdirectory(v:val)')
    let s:dirs = {}
    for dname in items
        let pname = fnamemodify(dname, ':t')
        if pname !~ g:enabler#exclude_rx && index(g:enabler#exclude_dirs, pname) == -1
            let s:dirs[pname] = dname
        endif
    endfor
endf


" Define a list of dependencies for a plugin.
"
" Examples:
"   call enabler#Dependency('vikitasks_vim', ['viki_vim'])
function! enabler#Dependency(plugin, dependencies) "{{{3
    let s:dependencies[a:plugin] = get(a:dependencies, a:plugin, []) + a:dependencies
    call s:AddUndefine(a:plugin, printf('call s:Remove(s:dependencies, %s)', string(a:plugin)))
endf


" Execute a vim command after enabling a plugin.
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


function! enabler#Complete(lead, line, col) "{{{3
    return join(keys(s:Dirs()), "\n")
endf


" :display: enabler#Plugin(plugins, ?load_now=0, ?[subdir_rxs])
" If load_now == 1, load the vim files right away.
function! enabler#Plugin(plugins, ...) "{{{3
    let fname_rxs = ['[\/]_enabler.vim$', '[\/]plugin[\/][^\/]\{-}\.vim$']
    let load_now = a:0 >= 1 && a:1 >= 1 ? a:1 : !has('vim_starting')
    if a:0 >= 2
        let fname_rxs += a:2
    endif
    " let fname_rx = '\('. join(fname_rxs, '\|') .'\)'
    let dirs = s:Dirs()
    let rtp = split(&rtp, ',')
    let files = []
    for pname in a:plugins
        if !has_key(dirs, pname)
            echoerr "Enabler: Unknown plugin:" pname
        elseif has_key(s:loaded, pname)
            continue
        else
            let s:loaded[pname] = 1
            if has_key(s:dependencies, pname)
                call enabler#Plugin(s:dependencies[a:plugin], load_now)
            endif
            let dir = dirs[pname]
            let ndir = len(dir) + len('/')
            if index(rtp, dir) == -1
                let rtp = insert(rtp, dir, s:rtp_pos)
                let s:rtp_pos += 1
                if has_key(s:undefine, pname)
                    for undef in s:undefine[pname]
                        if g:enabler#debug
                            exec undef
                        else
                            silent! exec undef
                        endif
                    endfor
                    call remove(s:undefine, pname)
                endif
                let adir = dir .'/after'
                if isdirectory(adir)
                    let rtp = insert(rtp, adir, -1)
                endif
                if load_now == 1
                    let vimfiles = split(glob(dir .'/**/*.vim'), '\n')
                    for fname_rx in fname_rxs
                        let sfiles = filter(copy(vimfiles), 'v:val =~# fname_rx')
                        let sfiles = map(sfiles, 'strpart(v:val, ndir)')
                        let files += sfiles
                    endfor
                endif
                call s:LoadConfig('bundle/'. pname)
            endif
        endif
    endfor
    let &rtp = join(rtp, ',')
    if load_now
        for file in files
            exec 'runtime' fnameescape(file)
        endfor
    endif
    for pname in a:plugins
        if has_key(s:onload, pname)
            for e in s:onload[pname]
                exec e
            endfor
        endif
    endfor
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
    if !has_key(s:loaded_config, a:name)
        if !empty(g:enabler#config_dir)
            let cfg = g:enabler#config_dir .'/'. a:name .'.vim'
            if filereadable(cfg)
                exec 'source' fnameescape(cfg)
            endif
        else
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
    let ps = filter(copy(a:000), '!has_key(s:loaded, v:val)')
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
    let ps = filter(copy(ps), '!has_key(s:loaded, v:val)')
    if !empty(ps)
        let s:ftplugins[a:ft] = get(s:ftplugins, a:ft, []) + ps
        for p in ps
            call s:AddUndefine(p, printf('call s:RemovePlugin(s:ftplugins, %s, %s)', string(a:ft), string(p)))
        endfor
    endif
endf


" :display: enabler#Command(plugin, "CMD DEF", ?OPTIONS={}) or enabler#Command(plugin, ["CMD", "DEF"], ?OPTIONS={})
function! enabler#Command(plugin, cmddef, ...) "{{{3
    if has_key(s:loaded, a:plugin)
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
        call s:AddUndefine(a:plugin, 'delcommand '. cmd)
    catch
        echohl Error
        echom "Enabler: Error when defining stub command:" sdef
        echom v:exception
        echohl NONE
    endtry
endf


function! s:EnableCommand(cmd, plugin, bang, range, args) "{{{3
    " exec 'delcommand' a:cmd
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
            echom "Exception" v:exception "from" v:throwpoint
            echom v:errmsg
            echohl NONE
        endtry
    else
        echohl Error
        echom "Enabler: Unknown command:" a:cmd
        echohl NONE
    endif
endf


" Define a dummy map that will load PLUGIN upon first invocation.
" Examples:
"   call enabler#Map('tmarks_vim', '<silent> <f2> :TMarks<cr>')
function! enabler#Map(plugin, args) "{{{3
    " echom "DBG enabler#Map" string(a:args) a:plugin
    if has_key(s:loaded, a:plugin)
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
            if item =~ '^.\?\(nore\)\?map$'
                let mcmd = item
            else
                let mode = 'args'
                continue
            endif
        elseif mode == 'args'
            if item =~ '^<\(buffer\|nowait\|silent\|special\|script\|expr\|unique\)>$'
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
    " TLogVAR lhs
    call feedkeys(lhs, 't')
endf


function! enabler#FuncUndefined(fn) "{{{3
    let autoloads = filter(copy(s:autoloads), 'a:fn =~ v:key')
    let plugins = []
    for ps in values(autoloads)
        let plugins += ps
    endfor
    call enabler#Plugin(plugins)
endf


function! enabler#AutoFiletype(ft) "{{{3
    call s:LoadConfig('ft/'. a:ft .'.vim')
    let ftplugins = get(s:ftplugins, a:ft, [])
    if !empty(ftplugins)
        call enabler#Plugin(ftplugins, 0, [
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

