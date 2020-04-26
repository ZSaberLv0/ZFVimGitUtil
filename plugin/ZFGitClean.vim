
function! ZF_GitClean()
    let cleanInfo = ZF_GitCleanInfo()
    if empty(cleanInfo['untracked']) && empty(cleanInfo['ignored'])
        redraw | echo '[ZFGitClean] already clean'
        return
    endif
    let lines = s:prepareLines(cleanInfo)
    call s:setupBuffer(lines)
    redraw
endfunction
command! -nargs=0 ZFGitClean :call ZF_GitClean()

" return: {
"   'untracked' : [],
"   'ignored' : [],
" }
function! ZF_GitCleanInfo()
    " Would remove path/xxx
    let ignoredMap = {}
    let ignored = []
    for item in split(system('git clean -d -n -X'), "\n")
        if match(item, '^Would remove') < 0
            continue
        endif
        call add(ignored, substitute(item, '^Would remove ', '', ''))
        let ignoredMap[item] = 1
    endfor

    let untracked = []
    for item in split(system('git clean -d -n -x'), "\n")
        if match(item, '^Would remove') < 0
                    \ || get(ignoredMap, item, 0)
            continue
        endif
        call add(untracked, substitute(item, '^Would remove ', '', ''))
    endfor

    return {
                \   'untracked' : untracked,
                \   'ignored' : ignored,
                \ }
endfunction

function! s:prepareLines(cleanInfo)
    let lines = []

    call extend(lines, [
                \   '',
                \   '# `:write` to perform cleanup',
                \   '# `:bdelete!` to cancel cleanup',
                \   '# remove or comment lines to prevent certain files from being deleted',
                \   '',
                \ ])

    call add(lines, '# untracked files:')
    call extend(lines, a:cleanInfo['untracked'])
    call add(lines, '')

    call add(lines, '# ignored files:')
    call extend(lines, a:cleanInfo['ignored'])
    call add(lines, '')

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
        call ZF_GitClean_rm(item)
    endfor
    execute 'bdelete ' . substitute(a:file, ' ', '\\ ', 'g')
    redraw
    ZFGitClean
endfunction

function! ZF_GitClean_rm(fileOrDir)
    if has('win32') || has('win64')
        call system('del /f/q "' . a:fileOrDir . '"')
        call system('rmdir /s/q "' . a:fileOrDir . '"')
    else
        call system('rm -rf "' . a:fileOrDir . '"')
    endif
endfunction

