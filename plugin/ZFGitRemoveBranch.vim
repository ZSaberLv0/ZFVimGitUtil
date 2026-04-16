
" remove local and remote branch
" or remove remote branch only if <bang>
"
" option: {
"   'confirm' : 1/0,
"   'force' : 0/1,
"   'local' : 1/0,
"   'remote' : 1/0,
" }
" return: {
"   'exitCode' : '',
"       // '0': success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_ERROR': internal error
"       // other: error
"   'output' : '',
" }
function! ZFGitRemoveBranch(toRemove, ...)
    let option = get(a:, 1, {})
    let confirm = get(option, 'confirm', 1)
    let force = get(option, 'force', 0)
    let removeLocal = get(option, 'local', 1)
    let removeRemote = get(option, 'remote', 1)

    let url = ZFGitGetRemoteUrl()
    if empty(url)
        echo 'unable to parse remote url'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to parse remote url',
                    \ }
    endif
    if ZFGitCheckSsh(url)
        echo 'ssh repo without ssh key'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'ssh repo without ssh key',
                    \ }
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
            return {
                        \   'exitCode' : 'ZF_ERROR',
                        \   'output' : 'can not remove current branch: ' . toRemove,
                        \ }
        elseif curBranch == 'HEAD'
            redraw
            echo 'can not work on detached HEAD'
            echo '    ' . toRemove
            return {
                        \   'exitCode' : 'ZF_ERROR',
                        \   'output' : 'can not work on detached HEAD: ' . toRemove,
                        \ }
        endif
    endif

    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitRemoveBranch',
                \   'confirm' : 0,
                \   'needPwd' : removeRemote,
                \ })
    if empty(gitInfo)
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'not git repo or canceled',
                    \ }
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
                return {
                            \   'exitCode' : 'ZF_ERROR',
                            \   'output' : 'no target to remove: ' . toRemove,
                            \ }
            endif
        endif
        if confirm
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
                return {
                            \   'exitCode' : 'ZF_CANCELED',
                            \   'output' : '',
                            \ }
            endif
        endif
    endif

    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    let ret = {
                \   'exitCode' : '0',
                \   'output' : '',
                \ }

    if removeLocal
        redraw
        echo 'removing local branch "' . toRemove . '" ... '
        let removeLocalResult = ZFGitCmd(printf('git branch %s "%s"'
                    \ , force ? '-D' : '-d'
                    \ , toRemove
                    \ ))
        if v:shell_error != '0'
            let ret['exitCode'] = 'ZF_ERROR'
            let ret['output'] = removeLocalResult
        endif
    endif

    if removeRemote
        redraw
        echo 'removing remote branch "' . toRemove . '" ... '
        let removeRemoteResult = ZFGitCmd(printf('git push "%s" --delete "%s"', remoteUrl, toRemove))
        let removeRemoteResult = substitute(removeRemoteResult, ':[^:]*@', '@', 'g')
        if v:shell_error != '0'
            let ret['exitCode'] = 'ZF_ERROR'
            if empty(ret['output'])
                let ret['output'] = removeLocalResult
            else
                let ret['output'] = ret['output'] . "\n" . removeLocalResult
            endif
        endif

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

    return ret
endfunction
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranch :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0)})
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranchLocal :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0), 'remote':0})
command! -nargs=* -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitRemoveBranchRemote :call ZFGitRemoveBranch(<q-args>, {'force' : (<q-bang> == '!' ? 1 : 0), 'local':0})

" remove all local branches except current one
"
" option: {
"   'force' : 0/1,
" }
" return: {
"   'exitCode' : '',
"       // 0: success
"       // 'ZF_CANCELED': canceled
"       // other: error
"   'output' : '',
"   'branches' : {
"     'xxx branch' : { // each result of ZFGitRemoveBranch
"       'exitCode' : '',
"       'output' : '',
"     },
"   },
" }
function! ZFGitRemoveBranchUnusedLocal(...)
    let option = get(a:, 1, {})
    let force = get(option, 'force', 0)
    let allBranch = ZFGitGetAllLocalBranch()
    if empty(allBranch)
        echo 'unable to obtain local branches'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain local branches',
                    \ }
    endif
    let curBranch = ZFGitGetCurBranch()
    if empty(curBranch)
        echo 'unable to obtain current branch'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain current branch',
                    \ }
    endif
    let index = index(allBranch, curBranch)
    if index >= 0
        call remove(allBranch, index)
    endif
    if empty(allBranch)
        echo 'only one local branch, no need to remove'
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'only one local branch, no need to remove',
                    \ }
    endif

    if force
        let hint = "\n[ZFGitRemoveBranch] about to remove all local branch except current:"
        for toRemove in allBranch
            let hint .= "\n    " . toRemove
        endfor
        let hint .= "\n"
        let hint .= "\nWARNING: can not undo"
        let hint .= "\nenter `got it` to continue: "
        call inputsave()
        let input = input(hint)
        call inputrestore()
        if input != 'got it'
            redraw
            echo 'canceled'
            return {
                        \   'exitCode' : 'ZF_CANCELED',
                        \   'output' : '',
                        \ }
        endif
    endif

    let ret = {
                \   'exitCode' : '0',
                \   'output' : '',
                \   'branches' : {},
                \ }
    let successList = []
    let failList = []
    for branch in allBranch
        let branchRet = ZFGitRemoveBranch(branch, {
                    \   'confirm' : 0,
                    \   'force' : force,
                    \   'local' : 1,
                    \   'remote' : 0,
                    \ })
        let ret['branches'][branch] = branchRet
        if branchRet['exitCode'] != '0'
            let ret['exitCode'] = 'ZF_ERROR'
            call add(failList, branch)
        else
            call add(successList, branch)
        endif
    endfor

    if !empty(failList)
        let ret['output'] = 'local branch remove failed:'
        for branch in failList
            let ret['output'] .= "\n    " . branch
        endfor
    endif
    if !empty(successList)
        if !empty(ret['output'])
            let ret['output'] .= "\n\n"
        endif
        let ret['output'] .= 'local branch removed:'
        for branch in successList
            let ret['output'] .= "\n    " . branch
        endfor
    endif

    redraw
    if !empty(ret['output'])
        echo ret['output']
    endif
    return ret
endfunction
command! -nargs=0 -bang ZFGitRemoveBranchUnusedLocal :call ZFGitRemoveBranchUnusedLocal({'force' : (<q-bang> == '!' ? 1 : 0)})

