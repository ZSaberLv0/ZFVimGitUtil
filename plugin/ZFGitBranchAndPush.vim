
" branch from current commit, push, then go back to current commit
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
function! ZFGitBranchAndPush(toBranch)
    let option = get(a:, 1, {})
    let mode = get(option, 'mode', '')

    let curBranch = ZFGitGetBranch()
    if empty(curBranch) || curBranch == 'HEAD'
        let curBranch = ZFGitGetCommit()
    endif
    if empty(curBranch)
        echo 'unable to obtain current branch or commit'
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain current branch or commit',
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
                \   'module' : 'ZFGitBranchAndPush',
                \   'needPwd' : 1,
                \   'confirm' : empty(mode) ? 1 : 0,
                \   'extraInfo' : {
                \      'branch to push: ' : a:toBranch,
                \   },
                \ })
    if empty(gitInfo)
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'canceled',
                    \ }
    endif

    redraw | echo 'pushing to branch: ' . a:toBranch

    let branchResult = ZFGitCmd('git checkout -b ' . a:toBranch)
    if exists('v:shell_error') && v:shell_error != 0
        redraw | echo 'branch failed: ' . branchResult
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'branch failed: ' . branchResult,
                    \ }
    endif

    redraw
    let exitCode = '0'
    let output = 'success'

    let taskResult = ZFGitPushQuickly({
                \   'mode' : '!',
                \ })
    if taskResult['exitCode'] != '0'
        redraw
        echo 'push failed: ' . taskResult['output']
        let exitCode = taskResult['exitCode']
        let output = taskResult['output']
    endif

    let restoreResult = ZFGitCmd('git checkout ' . curBranch)
    if exists('v:shell_error') && v:shell_error != 0
        echo restoreResult
        if exitCode == '0'
            let exitCode = v:shell_error
            let output = restoreResult
        endif
        echo 'branch restore failed: ' . restoreResult
    endif

    return {
                \   'exitCode' : exitCode,
                \   'output' : output,
                \ }
endfunction
command! -nargs=1 -complete=customlist,ZFGitCmdComplete_branch ZFGitBranchAndPush :call ZFGitBranchAndPush(<q-args>)

