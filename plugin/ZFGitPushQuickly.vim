
" push quickly
" option: {
"   'mode' : '',
"       // default : push with confirm
"       // '!' : push without confirm
"       // 'u' : pull only
"   'forcePushLocalCommits' : 0/1,
"   'comment' : 'push comment',
" }
"
" return: {
"   'exitCode' : '',
"       // '0': success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_ERROR': internal error
"       // 'ZF_CONFLICT': conflict
"       // other: error
"   'output' : '',
" }
function! ZFGitPushQuickly(...)
    let option = get(a:, 1, {})
    let comment = get(option, 'comment', '')
    if empty(comment)
        let comment = get(g:, 'ZFGitPushQuickly_defaultMsg', 'update')
    endif
    let mode = get(option, 'mode', '')

    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitPushQuickly',
                \   'needPwd' : 1,
                \   'confirm' : empty(mode) ? 1 : 0,
                \   'extraInfo' : {
                \      'msg' : comment,
                \   },
                \   'extraChoice' : {
                \     'u' : 'p(u)llOnly',
                \   },
                \ })
    if empty(gitInfo)
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'not git repo or canceled',
                    \ }
    endif
    if mode == 'u'
        let gitInfo.choice = 'u'
    endif

    let url = ZFGitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to parse remote url',
                    \ }
    endif
    if ZFGitCheckSsh(url)
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'ssh repo without ssh key',
                    \ }
    endif

    let gitStatus = ZFGitCmd('git status --porcelain --branch')
    let softPullMode = 0
    if ZF_GitMsgMatch(gitStatus, ZF_GitMsgFormat_containLocalCommits()) >= 0
        if get(option, 'forcePushLocalCommits', 0)
            let input = 'got it'
        else
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
        endif
        if input != 'got it'
            redraw!
            echo '[ZFGitPushQuickly] canceled'
            return {
                        \  'exitCode' : 'ZF_CANCELED',
                        \  'output' : 'canceled',
                        \ }
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
    call ZFGitCmd('git config user.email "' . gitInfo.git_user_email . '"')
    call ZFGitCmd('git config user.name "' . gitInfo.git_user_name . '"')
    for config in get(g:, 'zf_git_extra_config', [
                \   'git config core.filemode false',
                \   'git config core.autocrlf false',
                \   'git config core.safecrlf true',
                \ ])
        call ZFGitCmd(config)
    endfor

    call ZFGitCmd('git add -A')
    let stashResult = ZFGitCmd('git stash')
    if exists('v:shell_error') && v:shell_error != 0
        redraw!
        echo 'unable to stash: ' . stashResult
        return {
                    \   'exitCode' : '' . v:shell_error,
                    \   'output' : 'unable to stash: ' . stashResult,
                    \ }
    endif
    let branch = ZFGitGetBranch()
    if branch == 'HEAD'
        redraw!
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to parse git branch, maybe in detached HEAD?',
                    \ }
    endif
    if empty(branch)
        redraw!
        let branch = input('no branch, enter new branch name to create: ', 'master')
        redraw!
        if empty(branch)
            echo '[ZFGitPushQuickly] canceled'
            return {
                        \   'exitCode' : 'ZF_CANCELED',
                        \   'output' : 'canceled',
                        \ }
        endif
    endif
    call ZFGitCmd('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')

    if softPullMode
        let pullResult = ZFGitCmd('git pull "' . remoteUrl . '" "' . branch . '"')
    else
        let pullResult = ZFGitCmd('git reset --hard origin/' . branch)
        if !(exists('v:shell_error') && v:shell_error != '0')
            " pull only if remote branch exists
            call ZFGitCmd('git pull "' . remoteUrl . '" "' . branch . '"')
        endif
    endif

    call ZFGitCmd('git stash pop')
    let stashResult = ZFGitCmd('git status -s')
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
        call ZFGitCmd('git stash drop')
        call ZFGitCmd('git reset')
        return {
                    \   'exitCode' : 'ZF_CONFLICT',
                    \   'output' : msg,
                    \ }
    endif

    if gitInfo.choice == 'u'
        call ZFGitCmd('git reset HEAD')
        redraw!
        let msg = 'REPO: ' . url
        let msg .= "\n" . pullResult
        let msg .= "\n" . ZFGitCmd('git show -s --format=%B')
        echo msg
        return {
                    \   'exitCode' : '0',
                    \   'output' : msg,
                    \ }
    endif

    redraw!
    echo 'pushing... ' . url
    call ZFGitCmd('git add -A')
    call ZFGitCmd('git commit -m "' . comment . '"')
    let pushResult = ZFGitCmd('git push "' . remoteUrl . '" HEAD')
    if !exists('v:shell_error') || v:shell_error == 0
        call ZFGitCmd('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    else
        call ZFGitCmd('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
        " soft reset to undo commit,
        " prevent next push's hard reset from causing commits dropped
        call ZFGitCmd('git reset origin/' . branch)
    endif
    redraw!

    " try to auto update upstream
    let upstream = ZFGitCmd('git rev-parse --abbrev-ref ' . branch . '@{upstream}')
    if match(upstream, '[a-z]+\/' . branch) < 0
        " git 1.8.0 or above
        call ZFGitCmd('git branch --set-upstream-to=origin/' . branch . ' ' . branch)
        " git 1.7 or below
        call ZFGitCmd('git branch --set-upstream ' . branch . ' origin/' . branch)
    endif

    let pushResult = printf("REPO: %s\n%s", url, pushResult)
    " strip password
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    echo pushResult
    return {
                \   'exitCode' : '0',
                \   'output' : pushResult,
                \ }
endfunction
command! -nargs=? -bang ZFGitPushQuickly :call ZFGitPushQuickly({'mode' : <q-bang>, 'comment' : <q-args>})

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

