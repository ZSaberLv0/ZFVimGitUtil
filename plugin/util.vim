
if !exists('g:zf_git_extra_config')
    let g:zf_git_extra_config = [
                \   'git config core.filemode false',
                \   'git config core.autocrlf false',
                \   'git config core.safecrlf true',
                \   'git config core.quotepath false',
                \ ]
endif

let s:ZFGitPrepare_savedPwd = {}
let s:ZFGitPrepare_savedPwdPredict = {}

" store temporary git password
function! ZFGitPwdSet(git_remoteurl, git_user_name, git_user_pwd)
    if empty(git_user_pwd)
        unlet s:ZFGitPrepare_savedPwd[git_user_name . ':' . git_remoteurl]
        unlet s:ZFGitPrepare_savedPwdPredict[git_user_name]
    else
        let s:ZFGitPrepare_savedPwd[git_user_name . ':' . git_remoteurl] = git_user_pwd
        let s:ZFGitPrepare_savedPwdPredict[git_user_name] = git_user_pwd
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
"   git_pushurl
"   git_user_email
"   git_user_name
"   git_user_pwd
function! ZFGitPrepare(options)
    let module = get(a:options, 'module', 'ZFGit')
    let needPwd = get(a:options, 'needPwd', 0)
    let confirm = get(a:options, 'confirm', 1)
    let extraInfo = get(a:options, 'extraInfo', {})
    let extraChoice = get(a:options, 'extraChoice', {})
    let ret = ZFGitGetInfo()
    if empty(ret)
        return {}
    endif
    let choice = 'y'
    if ret.git_remotetype == 'ssh'
        let needPwd = 0
    endif

    if !empty(ret.git_user_name)
        let ret.git_user_pwd = get(s:ZFGitPrepare_savedPwd, ret.git_user_name . ':' . ret.git_remoteurl, ret.git_user_pwd)
        if empty(ret.git_user_pwd)
            let ret.git_user_pwd = get(s:ZFGitPrepare_savedPwdPredict, ret.git_user_name, ret.git_user_pwd)
        endif
    endif
    let reInput = 0
    while 1
        if reInput || empty(ret.git_user_email)
            let reInput = 1
            redraw
            call inputsave()
            let ret.git_user_email = input('[' . module . '] input email: ', ret.git_user_email)
            call inputrestore()
            if empty(ret.git_user_email)
                break
            endif
        endif
        if reInput || empty(ret.git_user_name)
            let reInput = 1
            redraw
            call inputsave()
            let ret.git_user_name = input('[' . module . '] input user name: ', ret.git_user_name)
            call inputrestore()
            if empty(ret.git_user_name)
                break
            endif
        endif
        if needPwd && reInput
            redraw
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
            redraw
            let items = [
                        \   ['repo', ZFGitGetRemoteUrl()],
                        \   ['branch', ZFGitGetCurBranch()],
                        \   ['', ''],
                        \   ['email', ret.git_user_email],
                        \   ['user', ret.git_user_name],
                        \ ]
            if needPwd
                let pwdFix = ret.git_user_pwd
                if len(pwdFix) > 3
                    let pwdFix = strpart(pwdFix, 0, 3) . repeat('*', len(pwdFix) - 3)
                endif
                call add(items, ['pwd', pwdFix])
            endif
            if !empty(extraInfo)
                call add(items, ['', ''])
                for key in keys(extraInfo)
                    call add(items, [key, extraInfo[key]])
                endfor
            endif

            echo '[' . module . '] process with these info?'
            call add(items, ['', ''])
            call s:alignedEcho(items)

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
            redraw
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

    redraw
    if empty(ret.git_user_email) || empty(ret.git_user_name)
        echo '[' . module . '] canceled'
        return {}
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
        let s:ZFGitPrepare_savedPwd[ret.git_user_name . ':' . ret.git_remoteurl] = ret.git_user_pwd
        let s:ZFGitPrepare_savedPwdPredict[ret.git_user_name] = ret.git_user_pwd
    endif

    return extend({
                \   'choice' : choice,
                \ }, ret)
endfunction
" [[key0,value0], [key1,value1], ...]
function! s:alignedEcho(items)
    let maxKeyLen = 0
    for item in a:items
        if len(item[0]) > maxKeyLen
            let maxKeyLen = len(item[0])
        endif
    endfor
    for item in a:items
        if empty(item[0]) && empty(item[1])
            echo ' '
        else
            echo '  ' . item[0] . repeat(' ', maxKeyLen - len(item[0])) . ': ' . item[1]
        endif
    endfor
endfunction

function! ZFGitGetRemoteUrl()
    let url = ZFGitCmd('git remote get-url --all origin')
    let url = substitute(url, '[\r\n]', '', 'g')
    " ^[a-z]+://
    if match(url, '^[a-z]\+://') < 0
        " old git has no `get-url`

        " http:
        "   origin\thttps://github.com/xxx/xxx (fetch)
        "   origin\thttps://github.com/xxx/xxx (push)
        "
        " ssh:
        "   origin  root@192.168.xx.xx:/path/sample (fetch)
        "   origin  root@192.168.xx.xx:/path/sample (push)
        let remote = ZFGitCmd('git remote -v')
        " (?<=origin[ \t]+)[^ \t]+(?=[ \t]+\(push\))
        let url = matchstr(remote, '\%(origin[ \t]\+\)\@<=[^ \t]\+\%([ \t]\+(push)\)\@=')
    endif
    return substitute(url, '://.\+@', '://', '')
endfunction

function! ZFGitGetCurBranch()
    let ret = substitute(ZFGitCmd('git rev-parse --abbrev-ref HEAD'), '[\r\n]', '', 'g')
    if v:shell_error == 0
        return ret
    else
        return ''
    endif
endfunction

function! ZFGitGetAllLocalBranch()
    let ret = []
    for line in split(ZFGitCmd('git branch'), "\n")
        " * (HEAD detached at bbb3ec7)
        " ^\* \(.*\)$
        if match(line, '^\* (.*)$') >= 0
            continue
        endif
        " * master
        " ^\*? *
        let line = substitute(line, '^\*\= *', '', '')
        if !empty(line) && index(ret, line) < 0
            call add(ret, line)
        endif
    endfor
    return ret
endfunction

function! ZFGitGetAllRemoteBranch()
    let ret = []
    for line in split(ZFGitCmd('git branch -r'), "\n")
        " origin/HEAD -> origin/master
        " .*\-> *
        let line = substitute(line, '.*\-> *', '', '')
        " ^ *origin\/
        let line = substitute(line, '^ *origin\/', '', '')
        if !empty(line) && index(ret, line) < 0
            call add(ret, line)
        endif
    endfor
    return ret
endfunction

function! ZFGitGetAllBranch()
    let tmp = {}
    for item in ZFGitGetAllLocalBranch()
        let tmp[item] = 1
    endfor
    for item in ZFGitGetAllRemoteBranch()
        let tmp[item] = 1
    endfor
    return sort(keys(tmp))
endfunction

function! ZFGitGetCurCommit()
    let ret = ZFGitCmd('git log -1 --format=format:"%H"')
    if v:shell_error == 0 && !empty(ret)
        return substitute(ret, '[\r\n]', '', 'g')
    else
        return ''
    endif
endfunction

function! ZFGitGetRemoteType(remoteUrl)
    " https?://
    if match(a:remoteUrl, 'https\=://') >= 0
        return 'http'
    else
        return 'ssh'
    endif
endfunction

function! ZFGitCheckSsh(url)
    if ZFGitGetRemoteType(a:url) != 'ssh'
        return 0
    endif

    redraw | echo 'checking whether ssh repo... ' . a:url

    " Fetching origin
    " Host key verification failed.
    " fatal: Could not read from remote repository.
    "
    " Please make sure you have the correct access rights
    " and the repository exists.
    " error: Could not fetch origin
    let tryFetch = ZFGitCmd('git fetch --all')
    if v:shell_error == '0'
        return 0
    endif

    let fetchHint = '    ' . tryFetch
    let fetchHint = substitute(fetchHint, '[\r\n]\+$', '', 'g')
    let fetchHint = substitute(fetchHint, '\([\r\n]\+\)', '\1    ', 'g')

    redraw
    let hint = "NOTE: ssh repo detected:"
    let hint .= "\n    " . a:url
    let hint .= "\n"
    let hint .= "\nfetch hint:"
    let hint .= "\n" . fetchHint
    let hint .= "\n"
    let hint .= "\nthere's no way to quick push without proper ssh key"
    let hint .= "\ntypically this is what you should do:"
    let hint .= "\n    ssh-keygen"
    let hint .= "\n    ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 YourServerUserName@YourServerDomain"
    let hint .= "\n"
    let hint .= "\nif you are sure it's setup properly"
    let hint .= "\n  (`git fetch --all` does not require password)"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw
        echo 'canceled'
        return 1
    endif
    return 0
endfunction

function! ZFGitConfigGet(cmd)
    let ret = substitute(ZFGitCmd(a:cmd), '[\r\n]', '', 'g')
    if ret == '='
        return ''
    else
        return ret
    endif
endfunction

function! ZFGitGetInfo()
    let ret = s:ZFGitGetInfo()
    if ret.git_remotetype != 'ssh'
        let pos = match(ret.git_remoteurl, '://') + len('://')
        " http://user:pwd@github.com/user/repo
        let ret.git_pushurl = strpart(ret.git_remoteurl, 0, pos) . ret.git_user_name . ':' . ret.git_user_pwd . '@' . strpart(ret.git_remoteurl, pos)
    else
        let ret.git_pushurl = ret.git_remoteurl
    endif
    return ret
endfunction
function! s:ZFGitGetInfo()
    let ret = {
                \   'git_remoteurl' : '',
                \   'git_pushurl' : '',
                \   'git_remotetype' : '',
                \   'git_user_email' : '',
                \   'git_user_name' : '',
                \   'git_user_pwd' : '',
                \ }

    let ret.git_remoteurl = ZFGitGetRemoteUrl()
    if empty(ret.git_remoteurl)
        return ret
    endif
    let ret.git_remotetype = ZFGitGetRemoteType(ret.git_remoteurl)

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

    let ret.git_user_email = ZFGitConfigGet('git config --local user.email')
    let ret.git_user_name = ZFGitConfigGet('git config --local user.name')
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

    let ret.git_user_email = ZFGitConfigGet('git config --global user.email')
    let ret.git_user_name = ZFGitConfigGet('git config --global user.name')
    if !empty(ret.git_user_email) && !empty(ret.git_user_name)
        if ret.git_user_email == get(g:, 'zf_git_user_email', '') && ret.git_user_name == get(g:, 'zf_git_user_name', '')
            let ret.git_user_pwd = get(g:, 'zf_git_user_token', '')
        endif
        return ret
    endif

    return ret
endfunction

function! ZFGitCmd(cmd)
    if exists('g:ZFGitCmd_log')
        let startTime = reltime()
        let ret = system(a:cmd)
        let costTime = float2nr(reltimefloat(reltime(startTime, reltime())) * 1000)
        call add(g:ZFGitCmd_log, printf("%s\t%s\t%s\t%s", v:shell_error, costTime, a:cmd, join(split(ret, "\n"), '\\n')))
        return ret
    else
        return system(a:cmd)
    endif
endfunction

" ============================================================
function! ZFGitGetAllConflictFiles(...)
    let param = get(a:, 1, {})
    if type(param) == type('')
        let gitShortStatusList = split(param, "\n")
    elseif type(param) == type([])
        let gitShortStatusList = param
    else
        let gitShortStatusList = split(ZFGitCmd('git status -s'), "\n")
    endif

    let conflictFiles = []
    " https://git-scm.com/docs/git-status#_short_format
    "
    " XY PATH
    " XY ORIG_PATH -> PATH
    for line in gitShortStatusList
        " ^[ \t]*(U.|.U)[ \t]+
        if match(line, '^[ \t]*\(U.\|.U\)[ \t]\+') < 0
            continue
        endif
        let file = substitute(line, '^[ \t]*\(U.\|.U\)[ \t]\+', '', '')

        " [ \t]+->[ \t]+
        if match(file, '[ \t]\+->[ \t]\+') >= 0
            call s:checkConflict(substitute(file, '[ \t]\+->[ \t]\+.*', '', ''), conflictFiles)
            call s:checkConflict(substitute(file, '.*[ \t]\+->[ \t]\+', '', ''), conflictFiles)
        else
            call s:checkConflict(file, conflictFiles)
        endif
    endfor
    return conflictFiles
endfunction
function! s:checkConflict(file, conflictFiles)
    let file = a:file

    " ^[ \t]*"
    let file = substitute(file, '^[ \t]*"', '', '')
    " "[ \t]*$
    let file = substitute(file, '"[ \t]*$', '', '')

    if !empty(file) && filereadable(file)
        call add(a:conflictFiles, file)
    endif
endfunction

" ============================================================
" ArgLead: aa/b
" line: aa/bb/cc
" to: aa/bb, instead: aa/bb/cc
function! ZFGitPathCompleteFix(line, ArgLead)
    if !empty(a:ArgLead)
                \ && match(a:line, '\V\^' . a:ArgLead) < 0
        return ''
    endif

    let match = matchstr(a:line, '\V\^' . a:ArgLead)
    let tail = strpart(a:line, len(match))
    let pos = match(tail, '/')
    if pos < 0
        return a:line
    else
        return match . strpart(tail, 0, pos + 1)
    endif
endfunction

function! ZFGitCmdComplete_branch(ArgLead, CmdLine, CursorPos)
    let tmp = {}
    for item in ZFGitCmdComplete_branch_local(a:ArgLead, a:CmdLine, a:CursorPos)
        let tmp[item] = 1
    endfor
    for item in ZFGitCmdComplete_branch_remote(a:ArgLead, a:CmdLine, a:CursorPos)
        let tmp[item] = 1
    endfor
    return sort(keys(tmp))
endfunction

function! ZFGitCmdComplete_branch_remote(ArgLead, CmdLine, CursorPos)
    let ret = []
    for branch in ZFGitGetAllRemoteBranch()
        let tmp = ZFGitPathCompleteFix(branch, a:ArgLead)
        if !empty(tmp)
            call add(ret, tmp)
        endif
    endfor
    return ret
endfunction

function! ZFGitCmdComplete_branch_local(ArgLead, CmdLine, CursorPos)
    let ret = []
    for branch in ZFGitGetAllLocalBranch()
        let tmp = ZFGitPathCompleteFix(branch, a:ArgLead)
        if !empty(tmp)
            call add(ret, tmp)
        endif
    endfor
    return ret
endfunction

function! ZFGitCmdComplete_changedPath(ArgLead, CmdLine, CursorPos)
    let statuses = ZFGitCmd('git status -s')
    if empty(statuses) || v:shell_error != '0'
        return []
    endif
    let ret = []
    for status in split(statuses, "\n")
        if len(status) <= 3
            continue
        endif
        " ^.{2} "?(.+)[\/"]*$
        let file = substitute(status, '^.\{2} "\=\(.\+\)[\/"]*$', '\1', '')
        if file == status
            continue
        endif
        let tmp = ZFGitPathCompleteFix(file, a:ArgLead)
        if !empty(tmp)
            call add(ret, tmp)
        endif
    endfor
    return sort(ret)
endfunction

