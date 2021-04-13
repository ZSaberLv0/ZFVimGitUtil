
" push quickly
function! ZF_GitPushQuickly(bang, ...)
    let comment = get(a:, 1)
    if empty(comment)
        let comment = get(g:, 'ZFGitPushQuickly_defaultMsg', 'update')
    endif

    let url = ZF_GitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZF_GitCheckSsh(url)
        return
    endif

    let gitStatus = system('git status')
    let softPullMode = 0
    if ZF_GitMsgMatch(gitStatus, ZF_GitMsgFormat_containLocalCommits()) >= 0
        let hint = "[ZFGitPushQuickly] WARNING: you have local commits not pushed,"
        let hint .= "\n    continue quick push may cause confused result,"
        let hint .= "\n    it's adviced to manually operate:"
        let hint .= "\n    * `git push` manually"
        let hint .= "\n    * `git reset origin/<branch>` to undo local commit and try again"
        let hint .= "\n"
        let hint .= "\nif you really know what you are doing,"
        let hint .= "\nenter `got it` to continue: "
        redraw!
        call inputsave()
        let input = input(hint)
        call inputrestore()
        if input != 'got it'
            redraw!
            echo '[ZFGitPushQuickly] canceled'
            return
        endif
        let softPullMode = 1
    endif

    let gitInfo = ZF_GitPrepare({
                \   'module' : 'ZFGitPushQuickly',
                \   'needPwd' : 1,
                \   'confirm' : empty(a:bang) ? 1 : 0,
                \   'extraInfo' : {
                \      'msg' : comment,
                \   },
                \   'extraChoice' : {
                \     'u' : 'p(u)llOnly',
                \   },
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

    redraw!
    echo 'updating... ' . url
    call system('git config user.email "' . gitInfo.git_user_email . '"')
    call system('git config user.name "' . gitInfo.git_user_name . '"')
    for config in get(g:, 'zf_git_extra_config', [
                \   'git config core.filemode false',
                \   'git config core.autocrlf false',
                \   'git config core.safecrlf true',
                \ ])
        call system(config)
    endfor

    call system('git add -A')
    call system('git stash')
    let branch = ZF_GitGetBranch()
    if branch == 'HEAD'
        redraw!
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return
    endif
    if empty(branch)
        redraw!
        let branch = input('no branch, enter new branch name to create: ', 'master')
        redraw!
        if empty(branch)
            echo '[ZFGitPushQuickly] canceled'
            return
        endif
    endif
    call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')

    if softPullMode
        let pullResult = system('git pull "' . remoteUrl . '" "' . branch . '"')
    else
        let pullResult = system('git reset --hard origin/' . branch)
        if ZF_GitMsgMatch(pullResult, ZF_GitMsgFormat_noRemoteBranch()) < 0
            " pull only if remote branch exists
            call system('git pull "' . remoteUrl . '" "' . branch . '"')
        endif
    endif

    let stashResult = system('git stash pop')
    let stashResultLines = split(stashResult, "\n")
    let conflictPatterns = ZF_GitMsgFormat_conflict()
    for stashResultLine in stashResultLines
        if ZF_GitMsgMatch(stashResultLine, conflictPatterns) >= 0
            call s:openConflictFiles(stashResultLines)

            " <<<<<<< Updated upstream
            " content A
            " =======
            " content B
            " >>>>>>> Stashed changes
            "
            " ^<<<<<<<+ .*$|^=======+$|^>>>>>>>+ .*$
            let @/ = '^<<<<<<<\+ .*$\|^=======\+$\|^>>>>>>>\+ .*$'
            normal! ggnzz

            redraw!
            echo stashResult
            call system('git stash drop')
            call system('git reset')
            return
        endif
    endfor

    if gitInfo.choice == 'u'
        call system('git reset HEAD')
        redraw!
        echo pullResult
        echo "\n"
        echo system('git show -s --format=%B')
        return
    endif

    redraw!
    echo 'pushing... ' . url
    call system('git add -A')
    call system('git commit -m "' . comment . '"')
    let pushResult = system('git push "' . remoteUrl . '" HEAD')
    if !exists('v:shell_error') || v:shell_error == 0
        call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    else
        " soft reset to undo commit,
        " prevent next push's hard reset from causing commits dropped
        call system('git reset origin/' . branch)
    endif
    redraw!

    " try to auto update upstream
    let upstream = system('git rev-parse --abbrev-ref ' . branch . '@{upstream}')
    if match(upstream, '[a-z]+\/' . branch) < 0
        " git 1.8.0 or above
        call system('git branch --set-upstream-to=origin/' . branch . ' ' . branch)
        " git 1.7 or below
        call system('git branch --set-upstream ' . branch . ' origin/' . branch)
    endif

    " strip password
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    echo pushResult
endfunction
command! -nargs=? -bang ZFGitPushQuickly :call ZF_GitPushQuickly(<q-bang>, <q-args>)

function! ZF_GitPushAllQuickly(gitRepoDirs, ...)
    let msg = get(a:, 1, 'update')
    let oldDir = getcwd()
    try
        redir => result
        for dir in a:gitRepoDirs
            silent execute 'cd ' . dir
            silent execute 'ZFGitPushQuickly! ' . msg
        endfor
    finally
        redir END
    endtry
    execute 'cd ' . oldDir
    redraw!
    echo result
    if has('clipboard')
        let @* = result
    endif
    let @" = result
endfunction

function! ZF_GitMsgMatch(text, patterns)
    for i in range(len(a:patterns))
        if match(a:text, a:patterns[i]) >= 0
            return i
        endif
    endfor
    return -1
endfunction

function! s:openConflictFiles(stashResultLines)
    let matcherList = ZF_GitMsgFormat_conflictFileMatcher()
    for line in split(system('git status'), "\n")
        for matcher in matcherList
            let file = substitute(line, matcher[0], matcher[1], '')
            if !empty(file) && filereadable(file)
                execute 'edit ' . substitute(file, ' ', '\\ ', 'g')
            endif
        endfor
    endfor
endfunction

