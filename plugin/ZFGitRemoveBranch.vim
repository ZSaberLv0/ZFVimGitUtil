
" remove local and remote branch
function! ZF_GitRemoveBranch(name)
    let url = ZF_GitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZF_GitCheckSsh(url)
        return
    endif

    let gitInfo = ZF_GitPrepare({
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

    let branch = ZF_GitGetBranch()
    if branch == a:name
        redraw!
        echo '[ZFGitRemoveBranch] can not remove current branch:'
        echo '    ' . a:name
        return
    endif

    let hint = "[ZFGitRemoveBranch] about to remove local and remote branch:"
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

    call system('git config user.email "' . gitInfo.git_user_email . '"')
    call system('git config user.name "' . gitInfo.git_user_name . '"')

    redraw!
    echo '[ZFGitRemoveBranch] removing local branch "' . a:name . '" ... '
    let removeLocalResult = system('git branch -d ' . a:name)

    redraw!
    echo '[ZFGitRemoveBranch] removing remote branch "' . a:name . '" ... '
    let pushResult = system('git push "' . remoteUrl . '" --delete ' . a:name)
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    call system('git fetch -p -P "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')

    redraw!
    echo 'remove local branch:'
    echo removeLocalResult
    echo "\n"
    echo 'remove remote branch:'
    echo pushResult
endfunction
command! -nargs=+ ZFGitRemoveBranch :call ZF_GitRemoveBranch(<q-args>)

