" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @GIT:         http://github.com/tomtom/enabler_vim/
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    103
" GetLatestVimScripts: 0 0 :AutoInstall: enabler.vim
" Enable plugins

if &cp || exists("loaded_enabler")
    finish
endif
let loaded_enabler = 100

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:enabler_autofile')
    "                                                 *autoenabler.vim*
    " If non-empty, |:Enablegenerate| writes stub commands to this file. 
    " You can use |:Autoenabler| (e.g. in |vimrc|) to load the file into 
    " vim.
    let g:enabler_autofile = split(&rtp, ',')[0] .'/autoenabler.vim'   "{{{2
endif


" :display: :Enable[!] PLUGINS ...
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

" :display: :Enablefilepattern REGEXP PLUGINS...
command! -nargs=+ -complete=custom,enabler#Complete Enablefilepattern call enabler#Filepattern(<f-args>)

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

" Generate stub commands for all parseable plugins/bundles in 
" |g:enabler#auto#dirs| and save to |g:enabler_autofile|.
" See also |enabler#auto#Generate()|.
command! -bar -nargs=* -complete=file Enablegenerate call enabler#auto#Generate(<f-args>)

" Load |g:enabler_autofile|.
command! -bar Autoenabler exec 'source' fnameescape(g:enabler_autofile)

" Generate help tags for all bundles in |g:enabler#dirs|.
command! -bar Enablehelptags call enabler#helptags#Generate()


augroup Enabler
    autocmd!
    autocmd FuncUndefined * call enabler#FuncUndefined(expand("<afile>"))
    autocmd FileType * call enabler#AutoFiletype(expand("<amatch>"))
    autocmd BufReadPre,BufNew * call enabler#Filetypepatterns(expand("<afile>"))
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
