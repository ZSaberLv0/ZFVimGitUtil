
" option: {
"   'autoPush' : '1/0, whether auto push',
" }
function! ZFGitHardRemoveFileHistory(localPath, ...)
    let option = get(a:, 1, {})
    let autoPush = get(option, 'autoPush', 1)

    if isdirectory(a:localPath)
        let localPath = substitute(a:localPath, '[\/\\]\+$', '', '') . '/*'
    else
        let localPath = a:localPath
    endif

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

        let gitInfo = ZFGitPrepare({
                    \   'module' : 'ZFGitHardRemoveFileHistory',
                    \   'needPwd' : 1,
                    \   'confirm' : 0,
                    \   'extraInfo' : {
                    \      'to remove' : localPath,
                    \   },
                    \ })
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
    redraw

    if autoPush
        echo 'running push --force'
        let finalResult = ZFGitCmd(printf('git push --force "%s" HEAD', gitInfo.git_pushurl))
    else
        let finalResult = 'file history removed: ' . localPath
        let finalResult .= "\n" . 'use `git push --force` to take effect'
    endif

    call ZFGitCmd('git reflog expire --expire=now --all')
    call ZFGitCmd('git gc --prune=now --aggressive')
    redraw
    echo finalResult
endfunction
command! -nargs=+ -complete=file ZFGitHardRemoveFileHistory :call ZFGitHardRemoveFileHistory(<q-args>)

