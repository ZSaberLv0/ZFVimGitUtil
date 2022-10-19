
function! ZFGitClean()
    let cleanInfo = ZFGitCleanInfo()
    if 1
                \ && empty(cleanInfo['modified'])
                \ && empty(cleanInfo['deleted'])
                \ && empty(cleanInfo['untracked'])
                \ && empty(cleanInfo['ignored'])
        redraw | echo '[ZFGitClean] already clean'
        return
    endif
    let lines = s:prepareLines(cleanInfo)
    call s:setupBuffer(cleanInfo, lines)
    redraw
endfunction
command! -nargs=0 ZFGitClean :call ZFGitClean()

" return: {
"   'modified' : {},
"   'deleted' : {},
"   'untracked' : {},
"   'ignored' : {},
" }
function! ZFGitCleanInfo()
    let modified = {}
    let deleted = {}
    let untracked = {}
    let ignored = {}

    " https://git-scm.com/docs/git-status#_short_format
    for item in split(s:runGitCmd('status -s --ignored'), "\n")
        if strlen(item) <= 4
            continue
        endif
        let X = item[0]
        let Y = item[1]

        let file = strpart(item, 3)
        " [ \t]->[ \t].*
        let file = substitute(file, '[ \t]->[ \t].*', '', '')
        " ^[ \t]*"
        let file = substitute(file, '^[ \t]*"', '', '')
        " "[ \t]*$
        let file = substitute(file, '"[ \t]*$', '', '')

        if 0
        elseif 0
                    \ || (X == '!' || Y == '!')
            let ignored[file] = 1
        elseif 0
                    \ || (X == 'D')
                    \ || (Y == 'D' && X != 'U')
            let deleted[file] = 1
        elseif 0
                    \ || (X == '?' || Y == '?')
                    \ || (X == 'A')
                    \ || (Y == 'A' && X =~# '[ A]')
            let untracked[file] = 1
        else
            let modified[file] = 1
        endif
    endfor

    return {
                \   'modified' : modified,
                \   'deleted' : deleted,
                \   'untracked' : untracked,
                \   'ignored' : ignored,
                \ }
endfunction

function! s:runGitCmd(cmd)
    return system('git -c "core.quotepath=false" ' . a:cmd)
endfunction

function! s:prepareLines(cleanInfo)
    let lines = []

    call extend(lines, [
                \   '',
                \   '# `q` to perform or cancel cleanup',
                \   '# remove or comment lines to prevent file from being cleanup',
                \   '',
                \ ])

    if !empty(a:cleanInfo['modified'])
        call add(lines, '# modified files:')
        call s:prepareLineItems(lines, sort(keys(a:cleanInfo['modified'])))
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['deleted'])
        call add(lines, '# deleted files:')
        call s:prepareLineItems(lines, sort(keys(a:cleanInfo['deleted'])))
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['untracked'])
        call add(lines, '# untracked files:')
        call s:prepareLineItems(lines, sort(keys(a:cleanInfo['untracked'])))
        call add(lines, '')
    endif

    if !empty(a:cleanInfo['ignored'])
        call add(lines, '# ignored files:')
        call s:prepareLineItems(lines, sort(keys(a:cleanInfo['ignored'])), 0)
        call add(lines, '')
    endif

    return lines
endfunction
function! s:prepareLineItems(lines, items, ...)
    let enable = get(a:, 1, 1)
    if enable
        let prefix = '    '
    else
        let prefix = '    # '
    endif
    for item in a:items
        call add(a:lines, prefix . item)
    endfor
endfunction

function! s:setupBuffer(cleanInfo, lines)
    tabnew
    enew
    call setline(1, a:lines)
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodified
    setlocal filetype=sh
    setlocal foldmethod=indent
    setlocal foldignore=
    setlocal foldlevel=128
    let b:ZFGitCleanInfo = a:cleanInfo
    nnoremap <buffer><silent> q :call ZFGitClean_action()<cr>
endfunction

function! ZFGitClean_action()
    redraw!
    echo '[ZFGitClean] perform cleanup?'
    if exists('*ZFBackupSave')
        echo '  (Y)es without backup'
    endif
    echo '  (y)es'
    echo '  (n)o / (q)uit'
    echo '  (e)dit'
    echo ''
    echo 'choice: '
    let confirm = nr2char(getchar())
    if confirm !=# 'y' && confirm !=# 'Y'
        if confirm ==# 'n' || confirm ==# 'q'
            bdelete!
        endif
        redraw | echo '[ZFGitClean] canceled'
        return
    endif
    let autoBackup = (confirm !=# 'Y')

    let toClean = []
    for item in getline(1, '$')
        if match(item, '^[ \t]*#') >= 0
                    \ || match(item, '^[ \t]*$') >= 0
            continue
        endif
        let item = substitute(item, '^[ \t]\+', '', 'g')
        let item = substitute(item, '[ \t]\+$', '', 'g')
        if !empty(item)
            call add(toClean, item)
        endif
    endfor

    let i = 0
    let iEnd = len(toClean)
    while i < iEnd
        redraw | echo '[ZFGitClean] (' . (i+1) . '/' . iEnd . ') cleanup: ' . fnamemodify(toClean[i], ':t')
        call s:cleanFileOrDir(toClean[i], autoBackup)
        let i += 1
    endwhile

    bdelete!
    ZFGitClean
endfunction

function! s:cleanFileOrDir(fileOrDir, autoBackup)
    if 0
    elseif exists("b:ZFGitCleanInfo['modified'][a:fileOrDir]") || exists("b:ZFGitCleanInfo['deleted'][a:fileOrDir]")
        if a:autoBackup
            call s:tryBackup(a:fileOrDir)
        endif
        call system('git reset HEAD "' . a:fileOrDir . '"')
        call system('git checkout "' . a:fileOrDir . '"')
    elseif exists("b:ZFGitCleanInfo['untracked'][a:fileOrDir]") || exists("b:ZFGitCleanInfo['ignored'][a:fileOrDir]")
        if a:autoBackup
            call s:tryBackup(a:fileOrDir)
        endif
        if exists("b:ZFGitCleanInfo['untracked'][a:fileOrDir]")
            call system('git reset HEAD "' . a:fileOrDir . '"')
        endif
        if (has('win32') || has('win64')) && !has('unix')
            call system('del /f/q "' . substitute(a:fileOrDir, '/', '\\', 'g') . '"')
            call system('rmdir /s/q "' . substitute(a:fileOrDir, '/', '\\', 'g') . '"')
        else
            call system('rm -rf "' . a:fileOrDir . '"')
        endif
    endif
endfunction

function! s:tryBackup(fileOrDir)
    if !exists('*ZFBackupSave')
        return
    endif

    if isdirectory(a:fileOrDir)
        call ZFBackupSaveDir(a:fileOrDir)
    else
        call ZFBackupSave(a:fileOrDir)
    endif
endfunction

