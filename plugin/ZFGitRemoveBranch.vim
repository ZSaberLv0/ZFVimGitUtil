
" remove local and remote branch
" or remove remote branch only if <bang>
"
" option: {
"   'mode' : '',
"       // '!' : force remove
"   'local' : 1/0,
"   'remote' : 1/0,
" }
function! ZFGitRemoveBranch(toRemove, ...)
    let option = get(a:, 1, {})

    let url = ZFGitGetRemoteUrl()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZFGitCheckSsh(url)
        return
    endif

    let targetInfo = ZFGitBranchPick(a:toRemove)
    if empty(targetInfo['branch'])
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'canceled',
                    \ }
    endif
    let toRemove = targetInfo['branch']

    if get(option, 'local', 1)
        let curBranch = ZFGitGetCurBranch()
        if curBranch == toRemove
            redraw
            echo 'can not remove current branch:'
            echo '    ' . toRemove
            return
        elseif curBranch == 'HEAD'
            redraw
            echo 'can not work on detached HEAD'
            echo '    ' . toRemove
            return
        endif
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
            redraw
            echo 'no target to remove'
            echo '    ' . toRemove
            return
        endif
    endif
    let hint .= "\n[ZFGitRemoveBranch] about to remove " . targetHint . " branch:"
    let hint .= "\n    " . toRemove
    let hint .= "\n"
    let hint .= "\nWARNING: can not undo"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw
        echo 'canceled'
        return
    endif

    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    if get(option, 'local', 1)
        redraw
        echo 'removing local branch "' . toRemove . '" ... '
        let removeLocalResult = ZFGitCmd(printf('git branch -D "%s"', toRemove))
    endif

    if get(option, 'remote', 1)
        redraw
        echo 'removing remote branch "' . toRemove . '" ... '
        let pushResult = ZFGitCmd(printf('git push "%s" --delete "%s"', remoteUrl, toRemove))
        let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
        call ZFGitCmd(printf('git fetch -p -P "%s" "+refs/heads/*:refs/remotes/origin/*"', remoteUrl))
    endif

    redraw
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
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranch :call ZFGitRemoveBranch(<q-args>, {'local' : (<q-bang> == '!' ? 0 : 1)})

