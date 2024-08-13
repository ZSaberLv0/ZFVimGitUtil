
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

    let targetInfo = ZFGitBranchPick(a:toBranch, {
                \   'title' : 'choose branch to merge to:',
                \ })
    if empty(targetInfo['branch'])
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'canceled',
                    \ }
    endif
    let toBranch = targetInfo['branch']

    if curBranch == toBranch
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'already on branch: ' . curBranch,
                    \ }
    endif

    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitMergeToAndPush',
                \   'needPwd' : 1,
                \   'confirm' : empty(mode) ? 1 : 0,
                \   'extraInfo' : {
                \      'merge and push: ' : printf('%s => %s', curBranch, toBranch),
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

    let mergeSuccess = 1
    call ZFGitCmd(printf('git checkout "%s"', toBranch))
    if v:shell_error == 0
        echo 'fetching branch: ' . toBranch
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
                let mergeSuccess = 0
            else
                redraw
                echo 'pushing to ' . toBranch . '... ' . gitInfo['git_remoteurl']

                silent! let pushResult = ZFGitPushQuickly({'mode' : '!', 'forcePushLocalCommits' : 1})
                if pushResult['exitCode'] != '0'
                    let exitCode = pushResult['exitCode']
                    let output = 'push failed: ' . pushResult['output']
                    call ZFGitCmd(printf('git reset --hard "origin/%s"', toBranch))
                else
                    let output = pushResult['output']
                    echo output
                endif
            endif
        endif
    else
        let branchResult = ZFGitCmd(printf('git checkout -b "%s"', toBranch))
        if v:shell_error == 0
            echo 'pushing to ' . toBranch . '... ' . gitInfo['git_remoteurl']
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

    if mergeSuccess
        let restoreResult = ZFGitCmd(printf('git checkout "%s"', curBranch))
        if v:shell_error != 0
            echo restoreResult
            if exitCode == '0'
                let exitCode = v:shell_error
                let output = 'branch restore failed: ' . restoreResult
            endif
        endif
    endif

    return {
                \   'exitCode' : exitCode,
                \   'output' : output,
                \ }
endfunction
command! -nargs=* -complete=customlist,ZFGitCmdComplete_branch ZFGitMergeToAndPush :call ZFGitMergeToAndPush(<q-args>, {'mode' : <q-bang>})

