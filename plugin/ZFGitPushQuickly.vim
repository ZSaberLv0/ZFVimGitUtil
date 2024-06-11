
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
            redraw
            call inputsave()
            let input = input(hint)
            call inputrestore()
        endif
        if input != 'got it'
            redraw
            echo 'canceled'
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

    redraw
    echo 'updating... ' . url
    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    let branch = ZFGitGetCurBranch()
    call ZFGitCmd('git add -A')
    let stashResult = ZFGitCmd('git stash')
    if v:shell_error != 0 && !empty(branch)
        redraw
        echo 'unable to stash: ' . stashResult
        return {
                    \   'exitCode' : '' . v:shell_error,
                    \   'output' : 'unable to stash: ' . stashResult,
                    \ }
    endif
    if branch == 'HEAD'
        redraw
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to parse git branch, maybe in detached HEAD?',
                    \ }
    endif
    if empty(branch)
        redraw
        let branch = input('no branch, enter new branch name to create: ', 'master')
        redraw
        if empty(branch)
            echo 'canceled'
            return {
                        \   'exitCode' : 'ZF_CANCELED',
                        \   'output' : 'canceled',
                        \ }
        endif
    endif
    call ZFGitCmd(printf('git fetch "%s" "+refs/heads/*:refs/remotes/origin/*"', remoteUrl))

    if softPullMode
        let pullResult = ZFGitCmd(printf('git pull "%s" "%s"', remoteUrl, branch))
    else
        let pullResult = ZFGitCmd(printf('git reset --hard "origin/%s"', branch))
        if v:shell_error == '0'
            " pull only if remote branch exists
            call ZFGitCmd(printf('git pull "%s" "%s"', remoteUrl, branch))
        endif
    endif

    call ZFGitCmd('git stash pop')
    let stashResult = ZFGitCmd('git status -s')
    silent let conflictFiles = ZFGitConflictOpen(split(stashResult, "\n"))
    if !empty(conflictFiles)
        redraw
        let msg = 'CONFLICTS:'
        for conflictFile in conflictFiles
            let msg .= "\n" . '    ' . conflictFile
        endfor
        call ZFGitCmd('git stash drop')
        call ZFGitCmd('git reset')
        echo msg
        return {
                    \   'exitCode' : 'ZF_CONFLICT',
                    \   'output' : msg,
                    \ }
    endif

    if gitInfo.choice == 'u'
        call ZFGitCmd('git reset HEAD')
        redraw
        let msg = 'REPO: ' . url
        let msg .= "\n" . pullResult
        let msg .= "\n" . ZFGitCmd('git show -s --format=%B')
        echo msg
        return {
                    \   'exitCode' : '0',
                    \   'output' : msg,
                    \ }
    endif

    redraw
    echo 'pushing... ' . url
    call ZFGitCmd('git add -A')
    call ZFGitCmd(printf('git commit -m "%s"', comment))
    let pushResult = ZFGitCmd(printf('git push "%s" HEAD', remoteUrl))
    if v:shell_error == 0
        call ZFGitCmd(printf('git fetch "%s" "+refs/heads/*:refs/remotes/origin/*"', remoteUrl))
    else
        call ZFGitCmd(printf('git fetch "%s" "+refs/heads/*:refs/remotes/origin/*"', remoteUrl))
        " soft reset to undo commit,
        " prevent next push's hard reset from causing commits dropped
        call ZFGitCmd(printf('git reset "origin/%s"', branch))
    endif
    redraw

    " try to auto update upstream
    let upstream = ZFGitCmd(printf('git rev-parse --abbrev-ref "%s@{upstream}"', branch))
    if match(upstream, '[a-z]+\/' . branch) < 0
        " git 1.8.0 or above
        call ZFGitCmd(printf('git branch --set-upstream-to="origin/%s" "%s"', branch, branch))
        " git 1.7 or below
        call ZFGitCmd(printf('git branch --set-upstream "%s" "origin/%s"', branch, branch))
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

