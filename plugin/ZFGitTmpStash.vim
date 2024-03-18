
command! -nargs=* -complete=customlist,ZFGitCmdComplete_changedPath ZFGitTmpStash :call ZFGitTmpStash(<q-args>)
command! -nargs=* -complete=customlist,ZFGitCmdComplete_stashDrop ZFGitTmpStashDrop :call ZFGitTmpStashDrop(<q-args>)
command! -nargs=0 ZFGitTmpStashList :call ZFGitTmpStashList()
command! -nargs=0 ZFGitTmpStashPop :call ZFGitTmpStashPop()

" ============================================================
function! ZFGitTmpStash(...)
    let fileOrEmpty = get(a:, 1, '')
    if fileOrEmpty == '*' || empty(fileOrEmpty)
        let statuses = ZFGitCmd(printf('git -c "core.quotepath=false" status -s'))
    else
        let statuses = ZFGitCmd(printf('git -c "core.quotepath=false" status -s "%s"', fileOrEmpty))
    endif
    if empty(statuses) || v:shell_error != '0'
        echo 'no changes'
        return
    endif
    let skippedHint = []
    let hint = []
    for status in split(statuses, "\n")
        if len(status) <= 3
            continue
        endif
        let X = status[0]
        let Y = status[1]
        " ^.{2} "?(.+?)[\/"]*$
        let file = substitute(status, '^.\{2} "\=\(.\{-1,}\)[\/"]*$', '\1', '')
        if file == status
            continue
        endif
        if isdirectory(file)
            call add(skippedHint, '    ' . file)
            continue
        endif

        if X == 'D' || (Y == 'D' && X != 'U')
            let p = fnamemodify(printf('%s/%s%s', s:basePath, s:delToken, file), ':h')
            if !empty(p)
                call mkdir(p, 'p')
            endif
            call writefile([], printf('%s/%s%s', s:basePath, s:delToken, file))
            call s:reset(file)
            call add(hint, '  D ' . file)
        else
            call s:cp(file, printf('%s/%s', s:basePath, file))
            if X == '?'
                call s:rm(file)
            else
                call s:reset(file)
            endif
            call add(hint, '    ' . file)
        endif
    endfor

    if empty(skippedHint) && empty(hint)
        echo 'no changes'
        return
    endif
    if !empty(skippedHint)
        if len(skippedHint) == 1
            echo 'skipped: ' . skippedHint[0]
        else
            echo 'skipped:'
            for item in skippedHint
                echo item
            endfor
        endif
    endif
    if !empty(hint)
        if len(hint) == 1
            echo 'stashed: ' . hint[0]
        else
            echo 'stashed:'
            for item in hint
                echo item
            endfor
        endif
    endif
endfunction

" param 0 : fileOrEmpty
" param 1 : {
"   'confirm' : 1/0,
" }
function! ZFGitTmpStashDrop(...)
    let fileOrEmpty = get(a:, 1, '')
    let option = get(a:, 2, {})
    let confirm = get(option, 'confirm', -1)
    if confirm == -1 && !empty(fileOrEmpty)
        let confirm = 0
    elseif confirm != 0
        let confirm = 1
    endif

    if empty(fileOrEmpty)
        let toCheck = []
        silent! let status = ZFGitTmpStashList()
        if !empty(status)
            for item in status['del']
                call add(toCheck, item)
            endfor
            for item in status['mod']
                call add(toCheck, item)
            endfor
        endif
    else
        let toCheck = [fileOrEmpty]
    endif

    while 1
        let hint = []
        for file in toCheck
            if filereadable(printf('%s/%s', s:basePath, file)) || isdirectory(printf('%s/%s', s:basePath, file))
                if !confirm
                    call s:rm(printf('%s/%s', s:basePath, file))
                endif
                call add(hint, '    ' . file)
            elseif filereadable(printf('%s/%s%s', s:basePath, s:delToken, file))
                if !confirm
                    call s:rm(printf('%s/%s%s', s:basePath, s:delToken, file))
                endif
                call add(hint, '  D ' . file)
            endif
        endfor
        if empty(hint)
            echo 'no stashes'
            return
        endif

        if confirm
            echo 'confirm to drop all stashes?'
            for item in hint
                echo item
            endfor
            echo "\n"
            let confirmHint = 'WARNING: can not undo'
            let confirmHint .= "\nenter `got it` to continue: "
            call inputsave()
            let input = input(confirmHint)
            call inputrestore()
            redraw
            if input != 'got it'
                echo 'canceled'
                return
            endif
            let confirm = 0
        else
            break
        endif
    endwhile

    if len(hint) == 1
        echo 'stash dropped: ' . hint[0]
    else
        echo 'stash dropped:'
        for item in hint
            echo item
        endfor
    endif

    if empty(fileOrEmpty)
        call s:rm(s:basePath)
    endif
endfunction

" return: {
"   'del' : ['xxx', 'xxx', ...],
"   'mod' : ['xxx', 'xxx', ...],
" }
" or return empty if none
function! ZFGitTmpStashList()
    let ret = {
                \   'del':[],
                \   'mod':[],
                \ }
    let result = split(glob(printf('%s/**', s:basePath), 1), "\n")
    for item in result
        if filereadable(item)
            let item = strpart(item, len(s:basePath) + 1)
            if stridx(item, s:delToken) == 0
                let item = strpart(item, len(s:delToken))
                call add(ret['del'], item)
            else
                call add(ret['mod'], item)
            endif
        endif
    endfor
    if empty(ret['del']) && empty(ret['mod'])
        echo 'no stashes'
        return {}
    endif

    echo 'stashes:'
    for item in ret['del']
        echo '  D ' . item
    endfor
    for item in ret['mod']
        echo '    ' . item
    endfor
    return ret
endfunction

" option: {
"   'confirm' : 1/0,
" }
function! ZFGitTmpStashPop(...)
    let option = get(a:, 1, {})
    silent! let status = ZFGitTmpStashList()
    if empty(status)
        echo 'no stashes'
        return
    endif

    let clean = 1
    if get(option, 'confirm', 1)
        echo 'stashes to apply:'
        for item in status['del']
            echo '  D ' . item
        endfor
        for item in status['mod']
            echo '    ' . item
        endfor
        echo "\n"
        echo 'confirm to apply stashes? [y/Y/n]: '
        let input = getchar()
        redraw
        if input != char2nr('y') && input != char2nr('Y')
            echo 'canceled'
            return
        endif
        if input == char2nr('Y')
            let clean = 0
        endif
    endif

    echo 'stashes applied:'
    for item in status['del']
        call s:rm(item)
        echo '  D ' . item
    endfor
    for item in status['mod']
        call s:cp(printf('%s/%s', s:basePath, item), item)
        echo '    ' . item
    endfor
    if clean
        call s:rm(s:basePath)
    endif
endfunction

let s:basePath = '.git/ZFGitTmpStash'
let s:delToken = '_ZFD_'

function! s:reset(file)
    call ZFGitCmd(printf('git reset HEAD "%s"', a:file))
    call ZFGitCmd(printf('git checkout "%s"', a:file))
endfunction

function! s:rm(fileOrDir)
    if (has('win32') || has('win64')) && !has('unix')
        call ZFGitCmd(printf('del /f/q "%s"', substitute(a:fileOrDir, '/', '\\', 'g')))
        call ZFGitCmd(printf('rmdir /s/q "%s"', substitute(a:fileOrDir, '/', '\\', 'g')))
    else
        call ZFGitCmd(printf('rm -rf "%s"', a:fileOrDir))
    endif
endfunction

function! s:cp(from, to)
    let p = fnamemodify(a:to, ':h')
    if !empty(p)
        call mkdir(p, 'p')
    endif
    if (has('win32') || has('win64')) && !has('unix')
        call ZFGitCmd(printf('copy /y "%s" "%s"', substitute(a:from, '/', '\', 'g'), substitute(a:to, '/', '\', 'g')))
    else
        call ZFGitCmd(printf('yes | cp "%s" "%s"', a:from, a:to))
    endif
endfunction

function! ZFGitCmdComplete_stashDrop(ArgLead, CmdLine, CursorPos)
    let ret = []
    silent! let status = ZFGitTmpStashList()
    for item in status['del']
        let tmp = ZFGitPathCompleteFix(item, a:ArgLead)
        if !empty(tmp)
            call add(ret, tmp)
        endif
    endfor
    for item in status['mod']
        let tmp = ZFGitPathCompleteFix(item, a:ArgLead)
        if !empty(tmp)
            call add(ret, tmp)
        endif
    endfor
    return sort(ret)
endfunction

