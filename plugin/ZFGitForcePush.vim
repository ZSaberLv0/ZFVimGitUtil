
command! -nargs=0 ZFGitForcePush :call ZFGitForcePush()

" ============================================================
" return: {
"   'exitCode' : '',
"       // '0': success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_ERROR': internal error
"       // other: error
"   'output' : '',
" }
function! ZFGitForcePush()
    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitForcePush',
                \   'needPwd' : 0,
                \   'confirm' : 0,
                \ })
    if empty(gitInfo)
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'output' : 'not git repo or canceled',
                    \ }
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
    let branch = ZFGitGetCurBranch()
    if empty(branch)
        return {
                    \   'exitCode' : 'ZF_ERROR',
                    \   'output' : 'unable to obtain current branch',
                    \ }
    endif

    let hint = 'REPO: ' . gitInfo.git_remoteurl
    let hint .= "\n[ZFGitForcePush] WARNING: about to force push by:"
    let hint .= "\n    1. delete remote branch"
    let hint .= "\n    2. push local branch"
    let hint .= "\n"
    let hint .= "\nif you really know what you are doing,"
    let hint .= "\nenter `got it` to continue: "
    redraw
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw
        echo 'canceled'
        return {
                    \  'exitCode' : 'ZF_CANCELED',
                    \  'output' : 'canceled',
                    \ }
    endif

    silent! let removeResult = ZFGitRemoveBranch(branch, {
                \   'confirm' : 0,
                \   'local' : 0,
                \   'remote' : 1,
                \ })
    if removeResult['exitCode'] != '0'
        return removeResult
    endif
    return ZFGitPushQuickly({
                \   'mode' : '!',
                \   'forcePushLocalCommits' : 1,
                \ })
endfunction

