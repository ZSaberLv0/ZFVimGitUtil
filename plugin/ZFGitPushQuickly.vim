
" push quickly
" bang:
"   * `!` : push without confirm
"   * `u` : pull only
function! ZFGitPushQuickly(bang, ...)
    let comment = get(a:, 1)
    if empty(comment)
        let comment = get(g:, 'ZFGitPushQuickly_defaultMsg', 'update')
    endif

    let gitInfo = ZFGitPrepare({
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
        return 'not git repo or canceled'
    endif
    if a:bang == 'u'
        let gitInfo.choice = 'u'
    endif

    let url = ZFGitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return 'unable to parse remote url'
    endif
    if ZFGitCheckSsh(url)
        return 'ssh repo without ssh key'
    endif

    let gitStatus = system('git status')
    let softPullMode = 0
    if ZF_GitMsgMatch(gitStatus, ZF_GitMsgFormat_containLocalCommits()) >= 0
        let hint = 'REPO: ' . url
        let hint .= "\n[ZFGitPushQuickly] WARNING: you have local commits not pushed,"
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
            return 'canceled'
        endif
        let softPullMode = 1
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
    let stashResult = system('git stash')
    if exists('v:shell_error') && v:shell_error != 0
        redraw!
        echo 'unable to stash: ' . stashResult
        return 'unable to stash: ' . stashResult
    endif
    let branch = ZFGitGetBranch()
    if branch == 'HEAD'
        redraw!
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return 'unable to parse git branch, maybe in detached HEAD?'
    endif
    if empty(branch)
        redraw!
        let branch = input('no branch, enter new branch name to create: ', 'master')
        redraw!
        if empty(branch)
            echo '[ZFGitPushQuickly] canceled'
            return 'canceled'
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

    call system('git stash pop')
    let stashResult = system('git status -s')
    let conflictFiles = []
    if s:openConflictFiles(split(stashResult, "\n"), conflictFiles) > 0
        " <<<<<<< Updated upstream
        " content A
        " =======
        " content B
        " >>>>>>> Stashed changes
        "
        " ^<<<<<<<+ .*$|^=======+$|^>>>>>>>+ .*$
        let @/ = '^<<<<<<<\+ .*$\|^=======\+$\|^>>>>>>>\+ .*$'
        call histadd('/', @/)
        normal! ggnzz

        redraw!
        let msg = 'CONFLICTS:'
        for conflictFile in conflictFiles
            let msg .= "\n" . '    ' . conflictFile
        endfor
        echo msg
        call system('git stash drop')
        call system('git reset')
        return msg
    endif

    if gitInfo.choice == 'u'
        call system('git reset HEAD')
        redraw!
        let msg = 'REPO: ' . url
        let msg .= "\n" . pullResult
        let msg .= "\n" . system('git show -s --format=%B')
        echo msg
        return msg
    endif

    redraw!
    echo 'pushing... ' . url
    call system('git add -A')
    call system('git commit -m "' . comment . '"')
    let pushResult = system('git push "' . remoteUrl . '" HEAD')
    if !exists('v:shell_error') || v:shell_error == 0
        call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    else
        call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
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

    let pushResult = printf("REPO: %s\n%s", url, pushResult)
    " strip password
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    echo pushResult
    return pushResult
endfunction
command! -nargs=? -bang ZFGitPushQuickly :call ZFGitPushQuickly(<q-bang>, <q-args>)

function! ZF_GitMsgMatch(text, patterns)
    for i in range(len(a:patterns))
        if match(a:text, a:patterns[i]) >= 0
            return i
        endif
    endfor
    return -1
endfunction

function! s:openConflictFiles(stashResult, conflictFiles)
    let ret = 0
    " https://git-scm.com/docs/git-status#_short_format
    "
    " XY PATH
    " XY ORIG_PATH -> PATH
    for line in a:stashResult
        " ^[ \t]*(U.|.U)[ \t]+
        if match(line, '^[ \t]*\(U.\|.U\)[ \t]\+') < 0
            continue
        endif
        let file = substitute(line, '^[ \t]*\(U.\|.U\)[ \t]\+', '', '')

        " [ \t]+->[ \t]+
        if match(file, '[ \t]\+->[ \t]\+') >= 0
            let ret += s:openConflictFile(substitute(file, '[ \t]\+->[ \t]\+.*', '', ''), a:conflictFiles)
            let ret += s:openConflictFile(substitute(file, '.*[ \t]\+->[ \t]\+', '', ''), a:conflictFiles)
        else
            let ret += s:openConflictFile(file, a:conflictFiles)
        endif
    endfor
    return ret
endfunction

function! s:openConflictFile(file, conflictFiles)
    let file = a:file

    " ^[ \t]*"
    let file = substitute(file, '^[ \t]*"', '', '')
    " "[ \t]*$
    let file = substitute(file, '"[ \t]*$', '', '')

    if !empty(file) && filereadable(file)
        call add(a:conflictFiles, file)
        execute 'edit ' . substitute(file, ' ', '\\ ', 'g')
        return 1
    else
        return 0
    endif
endfunction

