
function! ZF_GitClean()
    let cleanInfo = ZF_GitCleanInfo()
    if 1
                \ && empty(cleanInfo['modified'])
                \ && empty(cleanInfo['deleted'])
                \ && empty(cleanInfo['untracked'])
                \ && empty(cleanInfo['ignored'])
        redraw | echo '[ZFGitClean] already clean'
        return
    endif
    let lines = s:prepareLines(cleanInfo)
    call s:setupBuffer(lines)
    redraw
endfunction
command! -nargs=0 ZFGitClean :call ZF_GitClean()

" return: {
"   'modified' : [],
"   'deleted' : [],
"   'untracked' : [],
"   'ignored' : [],
" }
function! ZF_GitCleanInfo()
    " \tmodified:   path/file
    " \tdeleted:    path/file
    let modified = {}
    let deleted = {}
    for item in split(system('git status'), "\n")
        if 0
        elseif match(item, '^\tmodified: \+') >= 0
            " ^\tmodified: +
            let modified[substitute(item, '^\tmodified: \+', '', '')] = 1
        elseif match(item, '^\tdeleted: \+') >= 0
            " ^\tdeleted: +
            let deleted[substitute(item, '^\tdeleted: \+', '', '')] = 1
        endif
    endfor

    " Would remove path/xxx
    let ignoredMap = {}
    let ignored = {}
    for item in split(system('git clean -d -n -X'), "\n")
        if match(item, '^Would remove') < 0
            continue
        endif
        let ignored[substitute(item, '^Would remove ', '', '')] = 1
        let ignoredMap[item] = 1
    endfor

    let untracked = {}
    for item in split(system('git clean -d -n -x'), "\n")
        if match(item, '^Would remove') < 0
                    \ || get(ignoredMap, item, 0)
            continue
        endif
        let untracked[substitute(item, '^Would remove ', '', '')] = 1
    endfor

    return {
                \   'modified' : sort(keys(modified)),
                \   'deleted' : sort(keys(deleted)),
                \   'untracked' : sort(keys(untracked)),
                \   'ignored' : sort(keys(ignored)),
                \ }
endfunction

function! s:prepareLines(cleanInfo)
    let lines = []

    call extend(lines, [
                \   '',
                \   '# `:write` to perform cleanup',
                \   '# `:bdelete!` to cancel cleanup',
                \   '# remove or comment lines to prevent file from being reset or deleted',
                \   '',
                \ ])

    if !empty(a:cleanInfo['modified'])
        call add(lines, '# modified files:')
        call extend(lines, a:cleanInfo['modified'])
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['deleted'])
        call add(lines, '# deleted files:')
        call extend(lines, a:cleanInfo['deleted'])
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['untracked'])
        call add(lines, '# untracked files:')
        call extend(lines, a:cleanInfo['untracked'])
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['ignored'])
        call add(lines, '# ignored files:')
        call extend(lines, a:cleanInfo['ignored'])
        call add(lines, '')
    endif

    return lines
endfunction

function! s:setupBuffer(lines)
    let file = tempname()
    execute 'edit ' . substitute(file, ' ', '\\ ', 'g')
    call setline(1, a:lines)
    setlocal nomodified
    setlocal filetype=sh
    autocmd BufWritePost <buffer> call ZF_GitClean_action(expand('<afile>'))
endfunction

function! ZF_GitClean_action(file)
    redraw | echo '[ZFGitClean] perform cleanup, please wait...'

    for item in readfile(a:file)
        if match(item, '^[ \t]*#') >= 0
                    \ || match(item, '^[ \t]*$') >= 0
            continue
        endif
        let item = substitute(item, '^[ \t]\+', '', 'g')
        let item = substitute(item, '[ \t]\+$', '', 'g')
        if !empty(item)
            call ZF_GitClean_clean(item)
        endif
    endfor
    execute 'bdelete ' . substitute(a:file, ' ', '\\ ', 'g')
    redraw
    ZFGitClean
endfunction

function! ZF_GitClean_clean(fileOrDir)
    call system('git reset HEAD "' . a:fileOrDir . '"')
    if has('win32') || has('win64')
        call system('del /f/q "' . substitute(a:fileOrDir, '/', '\\', 'g') . '"')
        call system('rmdir /s/q "' . substitute(a:fileOrDir, '/', '\\', 'g') . '"')
    else
        call system('rm -rf "' . a:fileOrDir . '"')
    endif
    call system('git checkout "' . a:fileOrDir . '"')
endfunction

