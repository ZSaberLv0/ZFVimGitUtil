
" fetch from remote
"
" option: {
"   'prune' : 1/0, // whether perform --prune
"   'pruneLocal' : 1/0, // whether perform prune on local merged branches
"   'pruneLocalRef' : '', // ref name to perform 'git branch --merged'
"   'pruneLocalFilter' : 'pattern', // pattern to ignore from pruneLocal
"   'pruneLocalConfirm' : 1/0,
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
    let prune = get(option, 'prune', 1)
    let pruneLocal = prune && get(option, 'pruneLocal', 1)
    let pruneLocalRef = get(option, 'pruneLocalRef', '')
    let pruneLocalFilter = get(option, 'pruneLocalFilter', '')
    let pruneLocalConfirm = get(option, 'pruneLocalConfirm', 1)

    let gitInfo = ZFGitGetInfo()
    if gitInfo.git_remotetype != 'ssh'
        let pos = match(gitInfo.git_remoteurl, '://') + len('://')
        " http://user:pwd@github.com/user/repo
        let remoteUrl = strpart(gitInfo.git_remoteurl, 0, pos) . gitInfo.git_user_name . ':' . gitInfo.git_user_pwd . '@' . strpart(gitInfo.git_remoteurl, pos)
    else
        let remoteUrl = gitInfo.git_remoteurl
    endif

    redraw
    echo 'updating... ' . gitInfo.git_remoteurl
    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    let fetchResult = ZFGitCmd(printf('git fetch %s "%s" "+refs/heads/*:refs/remotes/origin/*"'
                \ , prune ? '-p -P' : ''
                \ , remoteUrl
                \ ))
    let exitCode = '' . v:shell_error
    let output = fetchResult
    redraw
    if empty(fetchResult)
        if exitCode == '0'
            let output = 'fetch success: ' . gitInfo.git_remoteurl
        else
            let output = 'fetch failed: ' . gitInfo.git_remoteurl
        endif
    endif

    if exitCode == '0' && pruneLocal
        let allRemoteBranch = ZFGitGetAllRemoteBranch()
        let curBranch = ZFGitGetCurBranch()
        for branch in split(ZFGitCmd(printf('git branch --merged%s'
                    \ , !empty(pruneLocalRef) ? printf(' "%s"', pruneLocalRef) : ''
                    \ )), "\n")
            " * master
            " ^\*? *
            let branch = substitute(branch, '^\*\= *', '', '')
            if 0
                        \ || branch == curBranch
                        \ || branch == 'master'
                        \ || branch == 'main'
                        \ || branch == 'staging'
                continue
            endif
            " * (HEAD detached at bbb3ec7)
            " ^\* \(.*\)$
            if match(branch, '^\* (.*)$') >= 0
                continue
            endif
            if !empty(pruneLocalFilter) && match(branch, pruneLocalFilter) >= 0
                continue
            endif
            " remove only if remote pruned
            let remoteExist = 0
            for remote in allRemoteBranch
                if branch == remote
                    let remoteExist = 1
                    break
                endif
            endfor
            if remoteExist
                continue
            endif

            let removeResult = ZFGitCmd(printf('git branch -d "%s"', branch))
            if v:shell_error == 0
                let removeResult = '* local branch pruned: ' . branch
            else
                let removeResult = '* local branch prune failed: ' . branch . ' : ' . removeResult
            endif
            let output .= "\n" . removeResult
        endfor
    endif

    echo output
    return {
                \   'exitCode' : exitCode,
                \   'output' : output,
                \ }
endfunction
command! -nargs=0 ZFGitFetch :call ZFGitFetch()

