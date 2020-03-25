" ZFVimGitUtil.vim - some git util for vim
" Author:  ZSaberLv0 <http://zsaber.com/>

" ============================================================
let s:scriptPath = expand('<sfile>:p:h:h') . '/misc/'

let s:ZF_GitPrepare_savedPwd = {}
let s:ZF_GitPrepare_savedPwdPredict = {}

" store temporary git password
function! ZF_GitPwdSet(git_remoteurl, git_user_name, git_user_pwd)
    if empty(git_user_pwd)
        unlet s:ZF_GitPrepare_savedPwd[git_user_name . ':' . git_remoteurl]
        unlet s:ZF_GitPrepare_savedPwdPredict[git_user_name]
    else
        let s:ZF_GitPrepare_savedPwd[git_user_name . ':' . git_remoteurl] = git_user_pwd
        let s:ZF_GitPrepare_savedPwdPredict[git_user_name] = git_user_pwd
    endif
endfunction

" prepare necessary git info
" options:
"   module : module name, ZFGit by default
"   needPwd : whether need pwd, false by default
"   confirm : whether need confirm, true by default
"   extraInfo : extra info when confirm, empty by default
"   extraChoice : {
"       'key1' : 'text1',
"       'key2' : 'text2',
"     }
" return empty or:
"   choice : y/extraChoice
"   git_remoteurl
"   git_user_email
"   git_user_name
"   git_user_pwd
function! ZF_GitPrepare(options)
    let module = get(a:options, 'module', 'ZFGit')
    let needPwd = get(a:options, 'needPwd', 0)
    let confirm = get(a:options, 'confirm', 1)
    let extraInfo = get(a:options, 'extraInfo', {})
    let extraChoice = get(a:options, 'extraChoice', {})
    let ret = ZF_GitGetInfo()
    if empty(ret)
        return
    endif
    let choice = 'y'

    let ret.git_user_pwd = get(s:ZF_GitPrepare_savedPwd, ret.git_user_name . ':' . ret.git_remoteurl, ret.git_user_pwd)
    if empty(ret.git_user_pwd)
        let ret.git_user_pwd = get(s:ZF_GitPrepare_savedPwdPredict, ret.git_user_name, ret.git_user_pwd)
    endif
    let reInput = 0
    while 1
        if reInput || empty(ret.git_user_email)
            let reInput = 1
            redraw!
            call inputsave()
            let ret.git_user_email = input('[' . module . '] input email: ', ret.git_user_email)
            call inputrestore()
            if empty(ret.git_user_email)
                break
            endif
        endif
        if reInput || empty(ret.git_user_name)
            let reInput = 1
            redraw!
            call inputsave()
            let ret.git_user_name = input('[' . module . '] input user name: ', ret.git_user_name)
            call inputrestore()
            if empty(ret.git_user_name)
                break
            endif
        endif
        if needPwd && reInput
            redraw!
            call inputsave()
            let ret.git_user_pwd = inputsecret('[' . module . '] input user pwd: ', ret.git_user_pwd)
            call inputrestore()
            if empty(ret.git_user_pwd)
                let ret.git_user_email = ''
                let ret.git_user_name = ''
                break
            endif
        endif

        if confirm
            redraw!
            echo '[' . module . '] process with these info?'
            echo '  email : ' . ret.git_user_email
            echo '  user  : ' . ret.git_user_name
            if needPwd
                let pwdFix = ret.git_user_pwd
                if len(pwdFix) > 3
                    let pwdFix = strpart(pwdFix, 0, 3) . repeat('*', len(pwdFix) - 3)
                endif
                echo '  pwd   : ' . pwdFix
            endif
            for key in keys(extraInfo)
                echo '  ' . key . ' : ' . extraInfo[key]
            endfor

            let choiceHint = '(y)es / (n)o / (e)dit'
            if !empty(extraChoice)
                for key in keys(extraChoice)
                    let choiceHint .= ' / ' . extraChoice[key]
                endfor
            endif
            echo choiceHint . ': '
            let c = nr2char(getchar())
            if c == 'e'
                let reInput = 1
                continue
            elseif index(keys(extraChoice), c) >= 0
                let choice = c
            elseif c != 'y'
                let ret.git_user_email = ''
                let ret.git_user_name = ''
                break
            endif
        endif

        if needPwd && empty(ret.git_user_pwd)
            redraw!
            call inputsave()
            let ret.git_user_pwd = inputsecret('[' . module . '] input user pwd: ', ret.git_user_pwd)
            call inputrestore()
            if empty(ret.git_user_pwd)
                let ret.git_user_email = ''
                let ret.git_user_name = ''
                break
            endif
        endif

        break
    endwhile

    redraw!
    if empty(ret.git_user_email) || empty(ret.git_user_name)
        echo '[' . module . '] canceled'
        return
    endif

    if empty(get(g:, 'zf_git_user_email', '')) || empty(get(g:, 'zf_git_user_name', ''))
        let g:zf_git_user_email = ret.git_user_email
        let g:zf_git_user_name = ret.git_user_name
        if !empty(ret.git_user_pwd)
            let g:zf_git_user_token = ret.git_user_pwd
        else
            unlet g:zf_git_user_token
        endif
    endif

    if needPwd
        let s:ZF_GitPrepare_savedPwd[ret.git_user_name . ':' . ret.git_remoteurl] = ret.git_user_pwd
        let s:ZF_GitPrepare_savedPwdPredict[ret.git_user_name] = ret.git_user_pwd
    endif

    return extend({
                \   'choice' : choice,
                \ }, ret)
endfunction

function! ZF_GitGetRemote()
    " supported:
    "   origin\thttps://github.com/xxx/xxx (fetch)
    "   origin\thttps://github.com/xxx/xxx (push)
    "
    " not supported:
    "   origin  root@192.168.xx.xx:/path/sample (fetch)
    "   origin  root@192.168.xx.xx:/path/sample (push)
    let remote = system('git remote -v')
    " (?<=origin[ \t]+)[^ \t]+(?=[ \t]+\(push\))
    let url = matchstr(remote, '\%(origin[ \t]\+\)\@<=[^ \t]\+\%([ \t]\+(push)\)\@=')
    if empty(url) || match(url, '://') < 0
        return ''
    endif
    let url = substitute(url, '://.\+@', '://', '')
    return url
endfunction

function! s:ZF_GitConfigGet(cmd)
    let ret = substitute(system(a:cmd), '[\r\n]', '', 'g')
    if ret == '='
        return ''
    else
        return ret
    endif
endfunction
function! ZF_GitGetInfo()
    let ret = {
                \   'git_remoteurl' : '',
                \   'git_user_email' : '',
                \   'git_user_name' : '',
                \   'git_user_pwd' : '',
                \ }

    let ret.git_remoteurl = ZF_GitGetRemote()
    if empty(ret.git_remoteurl)
        return ret
    endif

    for userSetting in get(g:, 'zf_git', [])
        if !empty(get(userSetting, 'repo', ''))
            if ret.git_remoteurl != userSetting['repo']
                continue
            endif
        elseif !empty(get(userSetting, 'repo_regexp', ''))
            if match(ret.git_remoteurl, userSetting['repo_regexp']) < 0
                continue
            endif
        else
            continue
        endif
        let ret.git_user_email = get(userSetting, 'git_user_email', '')
        let ret.git_user_name = get(userSetting, 'git_user_name', '')
        let ret.git_user_pwd = get(userSetting, 'git_user_pwd', '')
        if !empty(ret.git_user_email) && !empty(ret.git_user_name)
            if empty(ret.git_user_pwd) && ret.git_user_email == get(g:, 'zf_git_user_email', '') && ret.git_user_name == get(g:, 'zf_git_user_name', '')
                let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
            endif
            return ret
        endif
    endfor

    let ret.git_user_email = s:ZF_GitConfigGet('git config user.email')
    let ret.git_user_name = s:ZF_GitConfigGet('git config user.name')
    if !empty(ret.git_user_email) && !empty(ret.git_user_name)
        if ret.git_user_email == get(g:, 'zf_git_user_email', '') && ret.git_user_name == get(g:, 'zf_git_user_name', '')
            let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
        endif
        return ret
    endif

    let ret.git_user_email = get(g:, 'zf_git_user_email', '')
    let ret.git_user_name = get(g:, 'zf_git_user_name', '')
    if !empty(ret.git_user_email) && !empty(ret.git_user_name)
        let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
        return ret
    endif

    let ret.git_user_email = s:ZF_GitConfigGet('git config --global user.email')
    let ret.git_user_name = s:ZF_GitConfigGet('git config --global user.name')
    if !empty(ret.git_user_email) && !empty(ret.git_user_name)
        if ret.git_user_email == get(g:, 'zf_git_user_email', '') && ret.git_user_name == get(g:, 'zf_git_user_name', '')
            let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
        endif
        return ret
    endif

    return {}
endfunction

" hard remove all history of git repo
function! ZF_GitHardRemoveAllHistory()
    let url = ZF_GitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
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

" push quickly
function! ZF_GitPushQuickly(bang, ...)
    let comment = get(a:, 1)
    if empty(comment)
        let comment = get(g:, 'ZFGitPushQuickly_defaultMsg', 'update')
    endif

    let url = ZF_GitGetRemote()
    if empty(url)
        echo 'unable to parse remote url'
        return
    endif

    let gitStatus = system('git status')
    if match(gitStatus, 'Your branch is ahead of') >= 0
        let hint = "[ZFGitPushQuickly] WARNING: you have local commits not pushed,"
        let hint .= "\n    continue quick push may cause these commits lost,"
        let hint .= "\n    you may want to first resolve it manually by:"
        let hint .= "\n    * `git push` manually"
        let hint .= "\n    * `git reset origin/<branch>` to undo local commit and try again"
        let hint .= "\n"
        let hint .= "\nif you are sure remote contains your local commits which not pushed,"
        let hint .= "\nand really want to continue quick push,"
        let hint .= "\nenter `got it` to continue: "
        redraw!
        call inputsave()
        let input = input(hint)
        call inputrestore()
        if input != 'got it'
            redraw!
            echo '[ZFGitPushQuickly] canceled'
            return
        endif
    endif

    let gitInfo = ZF_GitPrepare({
                \   'module' : 'ZFGitPushQuickly',
                \   'needPwd' : 1,
                \   'confirm' : empty(a:bang) ? 1 : 0,
                \   'extraInfo' : {
                \      'repo ' : url,
                \      'msg  ' : comment,
                \   },
                \   'extraChoice' : {
                \     'u' : 'p(u)llOnly',
                \   },
                \ })
    if empty(gitInfo)
        return
    endif

    let pos = match(url, '://') + len('://')
    " http://user:pwd@github.com/user/repo
    let remoteUrl = strpart(url, 0, pos) . gitInfo.git_user_name . ':' . gitInfo.git_user_pwd . '@' . strpart(url, pos)

    redraw!
    echo 'updating... ' . url
    call system('git config user.email "' . gitInfo.git_user_email . '"')
    call system('git config user.name "' . gitInfo.git_user_name . '"')
    for config in get(g:, 'zf_git_extra_config', [
                \   'git config core.filemode false',
                \   'git config core.autocrlf false',
                \   'git config core.safecrlf true',
                \ ])
        call system(config)
    endfor

    call system('git add -A')
    call system('git stash')
    let branch = substitute(system('git rev-parse --abbrev-ref HEAD'), '[\r\n]', '', 'g')
    if branch == 'HEAD'
        redraw!
        echo 'unable to parse git branch, maybe in detached HEAD?'
        return
    endif
    if empty(branch)
        redraw!
        echo 'unable to parse git branch'
        return
    endif
    call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    let pullResult = system('git reset --hard origin/' . branch)
    if match(pullResult, 'unknown revision or path not in the working tree') < 0
        " pull only if remote branch exists
        call system('git pull "' . remoteUrl . '"')
    endif
    let stashResult = system('git stash pop')
    if match(stashResult, 'Merge conflict in ') >= 0
        " Auto-merging b.txt
        " CONFLICT (content): Merge conflict in b.txt
        " Auto-merging a.txt
        " CONFLICT (content): Merge conflict in a.txt
        let conflicts = []
        let s = stashResult
        while 1
            let c = match(s, '\%(Merge conflict in \)\@<=[^\r\n]\+')
            if c < 0
                break
            endif
            let p = matchstr(s, '\%(Merge conflict in \)\@<=[^\r\n]\+')
            call add(conflicts, p)
            let s = strpart(s, c + len(p))
        endwhile
        if !empty(conflicts)
            for conflict in conflicts
                execute 'edit ' . conflict
            endfor
        endif

        " <<<<<<< Updated upstream
        " content A
        " =======
        " content B
        " >>>>>>> Stashed changes
        let @/ = '^=======\+$'
        normal! ggnzz

        redraw!
        echo stashResult
        call system('git stash drop')
        return
    endif

    if gitInfo.choice == 'u'
        call system('git reset HEAD')
        redraw!
        echo pullResult
        echo "\n"
        echo system('git show -s --format=%B')
        return
    endif

    redraw!
    echo 'pushing... ' . url
    call system('git add -A')
    call system('git commit -m "' . comment . '"')
    let pushResult = system('git push "' . remoteUrl . '" HEAD')
    if !exists('v:shell_error') || v:shell_error == 0
        call system('git fetch "' . remoteUrl . '" "+refs/heads/*:refs/remotes/origin/*"')
    else
        " soft reset to undo commit,
        " prevent next push's hard reset from causing commits dropped
        call system('git reset origin/' . branch)
    endif
    redraw!
    " strip password
    let pushResult = substitute(pushResult, ':[^:]*@', '@', 'g')
    echo pushResult
endfunction
command! -nargs=? -bang ZFGitPushQuickly :call ZF_GitPushQuickly(<q-bang>, <q-args>)

function! ZF_GitPushAllQuickly(gitRepoDirs, ...)
    let msg = get(a:, 1, 'update')
    let oldDir = getcwd()
    redir => result
    for dir in a:gitRepoDirs
        execute 'cd ' . dir
        execute 'ZFGitPushQuickly! ' . msg
    endfor
    redir END
    execute 'cd ' . oldDir
    redraw!
    echo result
    if has('clipboard')
        let @* = result
    endif
    let @" = result
endfunction

