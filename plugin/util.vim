
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
    if ret.git_remotetype == 'ssh'
        let needPwd = 0
    endif

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
    " http:
    "   origin\thttps://github.com/xxx/xxx (fetch)
    "   origin\thttps://github.com/xxx/xxx (push)
    "
    " ssh:
    "   origin  root@192.168.xx.xx:/path/sample (fetch)
    "   origin  root@192.168.xx.xx:/path/sample (push)
    let remote = system('git remote -v')
    " (?<=origin[ \t]+)[^ \t]+(?=[ \t]+\(push\))
    let url = matchstr(remote, '\%(origin[ \t]\+\)\@<=[^ \t]\+\%([ \t]\+(push)\)\@=')
    return substitute(url, '://.\+@', '://', '')
endfunction

function! ZF_GitGetRemoteType(remoteUrl)
    " https?://
    if match(a:remoteUrl, 'https\=://') >= 0
        return 'http'
    else
        return 'ssh'
    endif
endfunction

function! ZF_GitCheckSsh(url)
    if ZF_GitGetRemoteType(a:url) != 'ssh'
        return 0
    endif

    " Fetching origin
    " Host key verification failed.
    " fatal: Could not read from remote repository.
    "
    " Please make sure you have the correct access rights
    " and the repository exists.
    " error: Could not fetch origin
    let tryFetch = system('git fetch --all')
    if match(tryFetch, 'Fetching origin') >= 0
                \ && match(tryFetch, 'Host key verification failed') < 0
                \ && match(tryFetch, 'Could not read from remote repository') < 0
                \ && match(tryFetch, 'Please make sure you have the correct access rights') < 0
                \ && match(tryFetch, 'Could not fetch origin') < 0
        return 0
    endif

    redraw!
    let hint = "NOTE: ssh repo detected:"
    let hint .= "\n    " . a:url
    let hint .= "\n"
    let hint .= "\nthere's no way to quick push without proper ssh key"
    let hint .= "\ntypically this is what you should do:"
    let hint .= "\n    ssh-keygen"
    let hint .= "\n    ssh-copy-id -i ~/.ssh/id_rsa.pub YourServerUserName@YourServerDomain"
    let hint .= "\n"
    let hint .= "\nif you are sure it's setup properly"
    let hint .= "\n  (`git fetch --all` does not require password)"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo 'canceled'
        return 1
    endif
    return 0
endfunction

function! ZF_GitConfigGet(cmd)
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
                \   'git_remotetype' : '',
                \   'git_user_email' : '',
                \   'git_user_name' : '',
                \   'git_user_pwd' : '',
                \ }

    let ret.git_remoteurl = ZF_GitGetRemote()
    if empty(ret.git_remoteurl)
        return ret
    endif
    let ret.git_remotetype = ZF_GitGetRemoteType(ret.git_remoteurl)

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

    let ret.git_user_email = ZF_GitConfigGet('git config user.email')
    let ret.git_user_name = ZF_GitConfigGet('git config user.name')
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

    let ret.git_user_email = ZF_GitConfigGet('git config --global user.email')
    let ret.git_user_name = ZF_GitConfigGet('git config --global user.name')
    if !empty(ret.git_user_email) && !empty(ret.git_user_name)
        if ret.git_user_email == get(g:, 'zf_git_user_email', '') && ret.git_user_name == get(g:, 'zf_git_user_name', '')
            let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
        endif
        return ret
    endif

    return {}
endfunction

