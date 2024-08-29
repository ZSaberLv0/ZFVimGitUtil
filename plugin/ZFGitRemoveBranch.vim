
" remove local and remote branch
" or remove remote branch only if <bang>
"
" option: {
"   'force' : 0/1,
"   'local' : 1/0,
"   'remote' : 1/0,
" }
function! ZFGitRemoveBranch(toRemove, ...)
    let option = get(a:, 1, {})
    let force = get(option, 'force', 0)
    let removeLocal = get(option, 'local', 1)
    let removeRemote = get(option, 'remote', 1)

    let url = ZFGitGetRemoteUrl()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZFGitCheckSsh(url)
        return
    endif

    let targetInfo = ZFGitBranchPick(a:toRemove, {
                \   'title' : 'choose branch to remove:',
                \   'local' : removeLocal,
                \   'remote' : removeRemote,
                \ })
    if empty(targetInfo['branch'])
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'canceled',
                    \ }
    endif
    let toRemove = targetInfo['branch']

    if removeLocal
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
                \   'confirm' : 0,
                \   'needPwd' : removeRemote,
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

    if removeRemote || force
        let hint = 'REPO: ' . gitInfo.git_remoteurl
        if removeLocal
            if removeRemote
                let targetHint = 'local and REMOTE'
            else
                let targetHint = 'local'
            endif
        else
            if removeRemote
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
    endif

    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    if removeLocal
        redraw
        echo 'removing local branch "' . toRemove . '" ... '
        let removeLocalResult = ZFGitCmd(printf('git branch %s "%s"'
                    \ , force ? '-D' : '-d'
                    \ , toRemove
                    \ ))
    endif

    if removeRemote
        redraw
        echo 'removing remote branch "' . toRemove . '" ... '
        let removeRemoteResult = ZFGitCmd(printf('git push "%s" --delete "%s"', remoteUrl, toRemove))
        let removeRemoteResult = substitute(removeRemoteResult, ':[^:]*@', '@', 'g')
        call ZFGitCmd(printf('git fetch -p "%s" "+refs/heads/*:refs/remotes/origin/*"', remoteUrl))
    endif

    redraw
    if removeLocal
        echo 'remove local branch:'
        echo removeLocalResult
    endif
    if removeRemote
        if removeLocal
            echo "\n"
        endif
        echo 'remove remote branch:'
        echo removeRemoteResult
    endif
endfunction
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranch :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0)})
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranchLocal :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0), 'remote':0})
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranchRemote :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0), 'local':0})

