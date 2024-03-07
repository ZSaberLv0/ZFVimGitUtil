
" merge current branch to specified branch, push, then go back to current branch
" if toBranch not exists, create a new one
"
" option: {
"   'mode' : '',
"       // '!' : push without confirm
" }
"
" return: {
"   'exitCode' : '',
"       // 0: success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_NO_REPO': no repo
"       // other: error
"   'output' : '',
" }
"
function! ZFGitMergeToAndPush(toBranch, ...)
    let option = get(a:, 1, {})
    let mode = get(option, 'mode', '')

    let curBranch = ZFGitGetCurBranch()
    if empty(curBranch)
        echo 'unable to obtain branch'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain branch',
                    \ }
    elseif curBranch == 'HEAD'
        echo 'can not work on detached HEAD'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'can not work on detached HEAD',
                    \ }
    endif

    let change = split(ZFGitCmd('git status -s'), "\n")
    if !empty(change)
        echo 'local changes not commited'
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'local changes not commited',
                    \ }
    endif

    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitMergeToAndPush',
                \   'needPwd' : 1,
                \   'confirm' : empty(mode) ? 1 : 0,
                \   'extraInfo' : {
                \      'merge and push: ' : printf('%s => %s', curBranch, a:toBranch),
                \   },
                \ })
    if empty(gitInfo)
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'canceled',
                    \ }
    endif

    redraw
    let exitCode = '0'
    let output = 'success'

    echo 'updating... ' . gitInfo.git_remoteurl
    call ZFGitFetch({
                \   'prune' : 0,
                \ })

    redraw

    call ZFGitCmd(printf('git checkout "%s"', a:toBranch))
    if v:shell_error == 0
        echo 'fetching branch: ' . a:toBranch
        let taskResult = ZFGitPushQuickly({
                    \   'mode' : 'u',
                    \ })
        if taskResult['exitCode'] != '0'
            redraw
            let exitCode = taskResult['exitCode']
            let output = 'fetch failed: ' . taskResult['output']
            echo output
        else
            redraw

            let mergeResult = ZFGitCmd(printf('git merge "%s"', curBranch))
            if v:shell_error != 0
                let exitCode = v:shell_error
                let output = mergeResult
                echo output
                echo "\n"
                echo printf('merge failed, reset branch "%s" to origin', a:toBranch)
                call ZFGitCmd(printf('git reset --hard "origin/%s"', a:toBranch))
            else
                redraw
                echo 'pushing to ' . a:toBranch . '... ' . gitInfo['git_remoteurl']

                silent! let pushResult = ZFGitPushQuickly({'mode' : '!', 'forcePushLocalCommits' : 1})
                if pushResult['exitCode'] != '0'
                    let exitCode = pushResult['exitCode']
                    let output = 'push failed: ' . pushResult['output']
                    call ZFGitCmd(printf('git reset --hard "origin/%s"', a:toBranch))
                else
                    let output = pushResult['output']
                    echo output
                endif
            endif
        endif
    else
        let branchResult = ZFGitCmd(printf('git checkout -b "%s"', a:toBranch))
        if v:shell_error == 0
            echo 'pushing to ' . a:toBranch . '... ' . gitInfo['git_remoteurl']
            let taskResult = ZFGitPushQuickly({
                        \   'mode' : '!',
                        \ })
            if taskResult['exitCode'] != '0'
                redraw
                let exitCode = taskResult['exitCode']
                let output = 'push failed: ' . taskResult['output']
                echo output
            endif
        else
            redraw
            let exitCode = 'ZF_ERROR'
            let output = 'branch failed: ' . branchResult
            echo output
        endif
    endif

    let restoreResult = ZFGitCmd(printf('git checkout "%s"', curBranch))
    if v:shell_error != 0
        echo restoreResult
        if exitCode == '0'
            let exitCode = v:shell_error
            let output = 'branch restore failed: ' . restoreResult
        endif
    endif

    return {
                \   'exitCode' : exitCode,
                \   'output' : output,
                \ }
endfunction
command! -nargs=1 -complete=customlist,ZFGitCmdComplete_branch ZFGitMergeToAndPush :call ZFGitMergeToAndPush(<q-args>, {'mode' : <q-bang>})
