
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
    if ZF_GitMsgMatch(gitStatus, ZF_GitMsgFormat_containLocalCommits()) >= 0
        let hint = "[ZFGitPushQuickly] WARNING: you have local commits not pushed,"
        let hint .= "\n    continue quick push may cause these commits lost,"
        let hint .= "\n    you may want to first resolve it manually by:"
        let hint .= "\n    * `git push` manually"
        let hint .= "\n    * `git reset origin/<branch>` to undo local commit and try again"
        let hint .= "\n"
        let hint .= "\nif you are sure remote contains your local commits which not pushed,"
        let hint .= "\nand really want to continue quick push,"
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
    endif

    let gitInfo = ZF_GitPrepare({
                \   'module' : 'ZFGitPushQuickly',
                \   'needPwd' : 1,
                \   'confirm' : empty(a:bang) ? 1 : 0,
                \   'extraInfo' : {
                \      'repo ' : url,
                \      'msg  ' : comment,
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
    let branch = substitute(system('git rev-parse --abbrev-ref HEAD'), '[\r\n]', '', 'g')
    if branch == 'HEAD'
        redraw!
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return
    endif
    if empty(branch)
        redraw!
        echo 'unable to parse git branch'
        return
    endif
    call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    let pullResult = system('git reset --hard origin/' . branch)
    if ZF_GitMsgMatch(pullResult, ZF_GitMsgFormat_noRemoteBranch()) < 0
        " pull only if remote branch exists
        call system('git pull "' . remoteUrl . '"')
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
            execute 'cd ' . dir
            execute 'ZFGitPushQuickly! ' . msg
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

