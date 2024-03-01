
" fetch from remote
"
" option: {
"   'prune' : 1/0, // whether perform --prune
" }
"
" return: {
"   'exitCode' : '',
"       // '0': success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_ERROR': internal error
"       // other: error
"   'output' : '',
" }
function! ZFGitFetch(...)
    let option = get(a:, 1, {})

    let gitInfo = ZFGitGetInfo()
    if gitInfo.git_remotetype != 'ssh'
        let pos = match(gitInfo.git_remoteurl, '://') + len('://')
        " http://user:pwd@github.com/user/repo
        let remoteUrl = strpart(gitInfo.git_remoteurl, 0, pos) . gitInfo.git_user_name . ':' . gitInfo.git_user_pwd . '@' . strpart(gitInfo.git_remoteurl, pos)
    else
        let remoteUrl = gitInfo.git_remoteurl
    endif

    redraw!
    echo 'updating... ' . gitInfo.git_remoteurl
    call ZFGitCmd('git config user.email "' . gitInfo.git_user_email . '"')
    call ZFGitCmd('git config user.name "' . gitInfo.git_user_name . '"')
    for config in get(g:, 'zf_git_extra_config', [
                \   'git config core.filemode false',
                \   'git config core.autocrlf false',
                \   'git config core.safecrlf true',
                \ ])
        call ZFGitCmd(config)
    endfor
    let fetchResult = ZFGitCmd('git fetch '
                \ . (get(option, 'prune', 0) ? '-p -P' : '')
                \ . ' "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    redraw
    if empty(fetchResult)
        let fetchResult = 'fetch success: ' . gitInfo.git_remoteurl
    endif
    echo fetchResult
    return {
                \   'exitCode' : '' . v:shell_error,
                \   'output' : fetchResult,
                \ }
endfunction
command! -nargs=0 -bang ZFGitFetch :call ZFGitFetch({'prune' : (<q-bang> == '!' ? 1 : 0)})

