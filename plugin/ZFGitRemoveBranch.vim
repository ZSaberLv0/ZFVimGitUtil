
" remove local and remote branch
" or remove remote branch only if <bang>
function! ZFGitRemoveBranch(name, ...)
    let bang = (get(a:, 1, '') == '!' ? 1 : 0)
    let url = ZFGitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZFGitCheckSsh(url)
        return
    endif

    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitRemoveBranch',
                \   'needPwd' : 1,
                \ })
    if empty(gitInfo)
        return
    endif

    if gitInfo.git_remotetype != 'ssh'
        let pos = match(url, '://') + len('://')
        " http://user:pwd@github.com/user/repo
        let remoteUrl = strpart(url, 0, pos) . gitInfo.git_user_name . ':' . gitInfo.git_user_pwd . '@' . strpart(url, pos)
    else
        let remoteUrl = url
    endif

    if !bang
        let curBranch = ZFGitGetBranch()
        if curBranch == a:name
            redraw!
            echo '[ZFGitRemoveBranch] can not remove current branch:'
            echo '    ' . a:name
            return
        endif
    endif

    let hint = 'REPO: ' . gitInfo.git_remoteurl
    if bang
        let hint .= "\n[ZFGitRemoveBranch] about to remove REMOTE branch:"
    else
        let hint .= "\n[ZFGitRemoveBranch] about to remove local and REMOTE branch:"
    endif
    let hint .= "\n    " . a:name
    let hint .= "\n"
    let hint .= "\nWARNING: can not undo"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo '[ZFGitRemoveBranch] canceled'
        return
    endif

    call ZFGitCmd('git config user.email "' . gitInfo.git_user_email . '"')
    call ZFGitCmd('git config user.name "' . gitInfo.git_user_name . '"')

    if !bang
        redraw!
        echo '[ZFGitRemoveBranch] removing local branch "' . a:name . '" ... '
        let removeLocalResult = ZFGitCmd('git branch -d ' . a:name)
    endif

    redraw!
    echo '[ZFGitRemoveBranch] removing remote branch "' . a:name . '" ... '
    let pushResult = ZFGitCmd('git push "' . remoteUrl . '" --delete ' . a:name)
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    call ZFGitCmd('git fetch -p -P "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')

    redraw!
    if !bang
        echo 'remove local branch:'
        echo removeLocalResult
        echo "\n"
    endif
    echo 'remove remote branch:'
    echo pushResult
endfunction
command! -nargs=+ -bang ZFGitRemoveBranch :call ZFGitRemoveBranch(<q-args>, <q-bang>)

