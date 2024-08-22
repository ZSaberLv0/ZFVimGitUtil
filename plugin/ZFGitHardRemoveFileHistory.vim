
function! ZFGitHardRemoveFileHistory(localPath)
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
    echo 'file history removed: ' . localPath
    echo 'use `git push --force` to take effect'
endfunction
command! -nargs=+ -complete=file ZFGitHardRemoveFileHistory :call ZFGitHardRemoveFileHistory(<q-args>)

