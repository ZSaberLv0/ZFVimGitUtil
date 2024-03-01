
" remove local and remote branch
" or remove remote branch only if <bang>
"
" option: {
"   'mode' : '',
"       // '!' : force remove
"   'local' : 1/0,
"   'remote' : 1/0,
" }
function! ZFGitRemoveBranch(name, ...)
    let option = get(a:, 1, {})

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

    if get(option, 'local', 1)
        let curBranch = ZFGitGetBranch()
        if curBranch == a:name
            redraw!
            echo 'can not remove current branch:'
            echo '    ' . a:name
            return
        elseif curBranch == 'HEAD'
            redraw!
            echo 'can not work on detached HEAD'
            echo '    ' . a:name
            return
        endif
    endif

    let hint = 'REPO: ' . gitInfo.git_remoteurl
    if get(option, 'local', 1)
        if get(option, 'remote', 1)
            let targetHint = 'local and REMOTE'
        else
            let targetHint = 'local'
        endif
    else
        if get(option, 'remote', 1)
            let targetHint = 'REMOTE'
        else
            redraw!
            echo 'no target to remove'
            echo '    ' . a:name
            return
        endif
    endif
    let hint .= "\n[ZFGitRemoveBranch] about to remove ' . targetHint . ' branch:"
    let hint .= "\n    " . a:name
    let hint .= "\n"
    let hint .= "\nWARNING: can not undo"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo 'canceled'
        return
    endif

    call ZFGitCmd('git config user.email "' . gitInfo.git_user_email . '"')
    call ZFGitCmd('git config user.name "' . gitInfo.git_user_name . '"')

    if get(option, 'local', 1)
        redraw!
        echo 'removing local branch "' . a:name . '" ... '
        let removeLocalResult = ZFGitCmd('git branch -D ' . a:name)
    endif

    if get(option, 'remote', 1)
        redraw!
        echo 'removing remote branch "' . a:name . '" ... '
        let pushResult = ZFGitCmd('git push "' . remoteUrl . '" --delete ' . a:name)
        let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
        call ZFGitCmd('git fetch -p -P "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    endif

    redraw!
    if get(option, 'local', 1)
        echo 'remove local branch:'
        echo removeLocalResult
        echo "\n"
    endif
    if get(option, 'remote', 1)
        echo 'remove remote branch:'
    endif
    echo pushResult
endfunction
command! -nargs=+ -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranch :call ZFGitRemoveBranch(<q-args>, {'local' : (<q-bang> == '!' ? 0 : 1)})

