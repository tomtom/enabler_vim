" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @GIT:         http://github.com/tomtom/enabler_vim/
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    85
" GetLatestVimScripts: 0 0 :AutoInstall: enabler.vim
" Enable plugins

if &cp || exists("loaded_enabler")
    finish
endif
let loaded_enabler = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:enabler_autofile')
    " If non-empty, load this file with enabler definitions on startup.
    let g:enabler_autofile = ''   "{{{2
endif


" :display: :Enableplugin[!] PLUGINS ...
" Enable one or more plugin. This will add the respective path to 
" 'runtimepath' and load the plugin file.
"
" When used from vimrc, plugins are loaded on the |VimEnter| event after 
" processing other startup files. With the optional |<bang>|, the plugin 
" is loaded right away.
"
" Before loading a bundle/plugin, a configuration file 
" `enabler/{BUNDLE}.vim` will be loaded. Most plugins allow users to 
" customize aspects of plugin behaviour by setting certain variables 
" before loading the plugin. See also |g:enabler#config_dir|.
"
" Example:
"   :Enable! tlib_vim
"   :Enable tcomment_vim checksyntax_vim
command! -bang -bar -nargs=+ -complete=custom,enabler#Complete Enable call enabler#Plugin([<f-args>], !empty("<bang>"))

" :display: :Enableautoload[!] REGEXP PLUGINS ...
" When an autoload function with a prefix matching REGEXP is loaded but 
" yet undefined (see |FuncUndefined|), load PLUGINS.
"
" Example:
"   :Enableautoload ^enable# enabler_vim
command! -bar -nargs=+ -complete=custom,enabler#Complete Enableautoload call enabler#Autoload(<f-args>)

" :display: :Enablefiletype[!] FILETYPE PLUGINS ...
" When 'filetype' is set, load PLUGINS.
"
" Before loading the plugins, the configuration file 
" `enabler/ft/{FILETYPE}.vim` will be loaded (see 
" |g:enabler#config_dir|).
"
" Example:
"   :Enablefiletype scala scala-vim
command! -bar -nargs=+ -complete=custom,enabler#Complete Enablefiletype call enabler#Ftplugin(<f-args>)

" :display: :Enablecommand[!] PLUGIN [OPTIONS] COMMAND
" Define a dummy COMMAND that will load PLUGINS upon first invocation.
" The dummy command will be deleted. It is assumed that one of the 
" loaded PLUGINS will redefine the command.
"
" OPTIONS is a list of |:command|'s arguments.
"
" Example:
"   :Enablecommand TMarks tmarks_vim
command! -bar -nargs=+ -complete=custom,enabler#Complete Enablecommand let s:tmp = [<f-args>] | call enabler#Command(s:tmp[0], s:tmp[1:-1]) | unlet! s:tmp

" :display: :Enablemap PLUGIN [MAPCMD] [MAPARGS] LHS [RHS]
" Call |enabler#Map()| with MAP and [PLUGIN] as arguments.
" By default |:map| is used as MAPCMD. If no RHS is defined, it is 
" assumed that PLUGIN will define the map.
"
" Examples:
"   :Enablermap tmarks_vim <silent> <f2> :TMarks<cr>
"   :Enablermap ttoc_vim inoremap <silent> <f10> :TToC<cr>
command! -nargs=+ -complete=custom,enabler#Complete Enablemap let s:tmp = [<f-args>] | call enabler#Map(s:tmp[0], s:tmp[1:-1]) | unlet! s:tmp

" Update the list of known plugins -- e.g. after installing a new 
" plugin while VIM is running.
command! -bar Enableupdate call enabler#Update()


command! -nargs=* -complete=file Enablegenerate call enabler#auto#Generate(<f-args>)


augroup Enabler
    autocmd!
    autocmd FuncUndefined * call enabler#FuncUndefined(expand("<afile>"))
    autocmd FileType * call enabler#AutoFiletype(expand("<amatch>"))
augroup END


if !empty(g:enabler_autofile) && filereadable(g:enabler_autofile)
    exec 'source' fnameescape(g:enabler_autofile)
endif


let &cpo = s:save_cpo
unlet s:save_cpo
