
let s:scriptPath = expand('<sfile>:p:h:h') . '/misc/'

" hard remove all history of git repo
function! ZFGitHardRemoveAllHistory()
    let gitInfo = ZFGitPrepare({
                \   'module' : 'ZFGitHardRemoveAllHistory',
                \   'needPwd' : 1,
                \ })
    if empty(gitInfo)
        return
    endif
    if ZFGitCheckSsh(gitInfo.git_remoteurl)
        return
    endif

    let hint = "[ZFGitHardRemoveAllHistory] WARNING: can not undo"
    let hint .= "\n    would use `push --force` to remove from remote"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw
        echo 'canceled'
        return
    endif

    call ZFGitCmd(printf('git config user.email "%s"', gitInfo.git_user_email))
    call ZFGitCmd(printf('git config user.name "%s"', gitInfo.git_user_name))
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
    endfor

    if (has('win32') || has('win64')) && !has('unix')
        let cmd = '"' . s:scriptPath . 'git_hard_remove_all_history.bat' . '"'
    else
        let cmd = 'sh "' . s:scriptPath . 'git_hard_remove_all_history.sh' . '"'
    endif
    let cmd .= ''
                \ . ' "."'
                \ . ' "' . gitInfo.git_user_email . '"'
                \ . ' "' . gitInfo.git_user_name . '"'
                \ . ' "' . gitInfo.git_user_pwd . '"'

    redraw
    echo 'running... ' . gitInfo['git_remoteurl']

    " strip password
    let pushResult = ZFGitCmd(cmd)
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    redraw
    let moreSaved = &more
    set nomore
    echo pushResult
    let &more = moreSaved
endfunction
command! -nargs=0 ZFGitHardRemoveAllHistory :call ZFGitHardRemoveAllHistory()

