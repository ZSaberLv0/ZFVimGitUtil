
" option: {
"   'autoPush' : '1/0, whether auto push',
" }
function! ZFGitHardRemoveFileHistory(localPath, ...)
    let option = get(a:, 1, {})
    let autoPush = get(option, 'autoPush', 1)

    if autoPush
        let hint = "[ZFGitHardRemoveFileHistory] WARNING: can not undo"
        let hint .= "\n    would use `push --force` to remove from remote"
        let hint .= "\nenter `got it` to continue: "
        call inputsave()
        let input = input(hint)
        call inputrestore()
        if input != 'got it'
            redraw
            echo 'canceled'
            return
        endif
    endif

    if isdirectory(a:localPath)
        let localPath = substitute(a:localPath, '[\/\\]\+$', '', '') . '/*'
    else
        let localPath = a:localPath
    endif

    redraw
    echo 'removing file history... ' . localPath
    let rmResult = ZFGitCmd(printf('git filter-branch --force --index-filter %sgit rm --cached --ignore-unmatch "%s"%s --prune-empty --tag-name-filter cat -- --all'
                \ , "'"
                \ , localPath
                \ , "'"
                \ ))
    if v:shell_error != '0'
        echo rmResult
        return
    endif

    call ZFGitCmd('git reflog expire --expire=now --all')
    call ZFGitCmd('git gc --prune=now --aggressive')
    redraw

    if autoPush
        let pushResult = ZFGitCmd(printf('git push --force "%s" HEAD', gitInfo.git_pushurl))
        echo pushResult
    else
        echo 'file history removed: ' . localPath
        echo 'use `git push --force` to take effect'
    endif
endfunction
command! -nargs=+ -complete=file ZFGitHardRemoveFileHistory :call ZFGitHardRemoveFileHistory(<q-args>)

