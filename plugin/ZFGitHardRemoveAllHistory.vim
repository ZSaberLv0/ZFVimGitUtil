
let s:scriptPath = expand('<sfile>:p:h:h') . '/misc/'

" hard remove all history of git repo
function! ZF_GitHardRemoveAllHistory()
    let url = ZF_GitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif
    if ZF_GitCheckSsh(url)
        return
    endif

    let gitInfo = ZF_GitPrepare({
                \   'module' : 'ZFGitHardRemoveAllHistory',
                \   'needPwd' : 1,
                \   'extraInfo' : {
                \      'repo ' : url,
                \   },
                \ })
    if empty(gitInfo)
        return
    endif

    let hint = "[ZFGitHardRemoveAllHistory] WARNING: can not undo"
    let hint .= "\n    would use `push --force` to remove from remote"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo '[ZFGitHardRemoveAllHistory] canceled'
        return
    endif

    call system('git config user.email "' . gitInfo.git_user_email . '"')
    call system('git config user.name "' . gitInfo.git_user_name . '"')

    if has('win32') || has('win64')
        let cmd = '"' . s:scriptPath . 'git_hard_remove_all_history.bat' . '"'
    else
        let cmd = 'sh "' . s:scriptPath . 'git_hard_remove_all_history.sh' . '"'
    endif
    let cmd .= ''
                \ . ' "."'
                \ . ' "' . gitInfo.git_user_email . '"'
                \ . ' "' . gitInfo.git_user_name . '"'
                \ . ' "' . gitInfo.git_user_pwd . '"'

    redraw!
    echo '[ZFGitHardRemoveAllHistory] running... ' . gitInfo['git_remoteurl']

    " strip password
    let pushResult = system(cmd)
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    redraw!
    echo pushResult
endfunction
command! -nargs=0 ZFGitHardRemoveAllHistory :call ZF_GitHardRemoveAllHistory()

