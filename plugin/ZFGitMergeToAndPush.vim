
" merge current branch to specified branch, push, then go back to current branch
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

    let curBranch = ZFGitGetBranch()
    if empty(curBranch)
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain branch',
                    \ }
    endif

    let change = split(ZFGitCmd('git status -s'), "\n")
    if !empty(change)
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

    redraw | echo 'checking out branch: ' . a:toBranch

    call ZFGitCmd('git checkout ' . a:toBranch)
    if exists('v:shell_error') && v:shell_error != 0
        redraw | echo 'target branch not exist: ' . a:toBranch
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'target branch not exist: ' . a:toBranch,
                    \ }
    endif

    let taskResult = ZFGitPushQuickly({
                \   'mode' : 'u',
                \ })
    if taskResult['exitCode'] != '0'
        redraw
        echo 'fetch failed: ' . taskResult['output']

        let restoreResult = ZFGitCmd('git checkout ' . curBranch)
        if exists('v:shell_error') && v:shell_error != 0
            echo 'branch restore failed: ' . restoreResult
        endif

        return {
                    \   'exitCode' : taskResult['exitCode'],
                    \   'output' : 'fetch failed: ' . taskResult['output'],
                    \ }
    endif

    redraw
    let exitCode = '0'
    let output = 'success'

    let mergeResult = ZFGitCmd('git merge ' . curBranch)
    if exists('v:shell_error') && v:shell_error != 0
        let exitCode = v:shell_error
        let output = mergeResult
        echo output
        echo "\n"
        echo printf('merge failed, reset branch "%s" to origin', a:toBranch)
        call ZFGitCmd('git reset --hard origin/' . a:toBranch)
    else
        redraw
        echo 'pushing to ' . a:toBranch . '... ' . gitInfo['git_remoteurl']

        silent! let pushResult = ZFGitPushQuickly({'mode' : '!', 'forcePushLocalCommits' : 1})
        if pushResult['exitCode'] != '0'
            echo 'push failed: ' . pushResult['output']
            call ZFGitCmd('git reset --hard origin/' . a:toBranch)
        else
            echo pushResult['output']
        endif
    endif

    let restoreResult = ZFGitCmd('git checkout ' . curBranch)
    if exists('v:shell_error') && v:shell_error != 0
        echo restoreResult
        let exitCode = v:shell_error
        let output = restoreResult
        echo 'branch restore failed: ' . output
    endif

    return {
                \   'exitCode' : exitCode,
                \   'output' : output,
                \ }
endfunction
command! -nargs=1 ZFGitMergeToAndPush :call ZFGitMergeToAndPush(<q-args>, {'mode' : <q-bang>})

