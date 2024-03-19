
command! -nargs=? -bang -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>, {'force' : (<q-bang> == '!')})

" option: {
"   'force' : 0/1, // whether try to perform `git reset --hard origin/<branch>`
"                  // valid only if remote branch exists
" }
"
" return: branch name if success, or empty if fail
function! ZFGitCheckout(branch, ...)
    let option = get(a:, 1, {})
    let force = get(option, 'force', 0)

    if !empty(a:branch) && stridx(a:branch, '*') < 0
        let allBranch = ZFGitGetAllBranch()
        if index(allBranch, a:branch) >= 0
                    \ || filereadable(a:branch)
                    \ || isdirectory(a:branch)
                    \ || !empty(split(ZFGitCmd(printf('git status -s "%s"', a:branch)), "\n"))
            echo ZFGitCmd(printf('git checkout "%s"', a:branch))
            if v:shell_error == 0 && index(ZFGitGetAllRemoteBranch(), a:branch) >= 0
                echo ZFGitCmd(printf('git reset --hard "origin/%s"', a:branch))
            endif
            return (v:shell_error == 0 ? a:branch : '')
        endif
        echo 'branch not exist:'
        echo '    ' . a:branch
        echo "\n"
        echo 'create and switch to new branch? [y/n]: '
        let choice = nr2char(getchar())
        redraw
        if choice != 'y' && choice != 'Y'
            echo 'checkout canceled: ' . a:branch
            return ''
        endif
        echo ZFGitCmd(printf('git checkout -b "%s"', a:branch))
        return (v:shell_error == 0 ? a:branch : '')
    endif

    let pattern = substitute(a:branch, '\.', '\\\.', 'g')
    let pattern = substitute(pattern, '\*', '\.\*', 'g')
    let curBranch = ZFGitGetCurBranch()

    let localBranch = ZFGitGetAllLocalBranch()
    let i = len(localBranch) - 1
    while i >= 0
        if match(localBranch[i], pattern) < 0
            call remove(localBranch, i)
        endif
        let i -= 1
    endwhile
    call reverse(localBranch)
    let curBranchIndex = index(localBranch, curBranch)
    if curBranchIndex > 0 && curBranchIndex < len(localBranch)
        call remove(localBranch, curBranchIndex)
        call insert(localBranch, curBranch, 0)
    endif

    let remoteBranch = ZFGitGetAllRemoteBranch()
    let i = len(remoteBranch) - 1
    while i >= 0
        if match(remoteBranch[i], pattern) < 0
                    \ || index(localBranch, remoteBranch[i]) >= 0
            call remove(remoteBranch, i)
        endif
        let i -= 1
    endwhile
    call reverse(remoteBranch)

    if exists('*ZF_VimCmdMenuShow')
        let target = s:choice_ZFVimCmdMenu(curBranch, localBranch, remoteBranch)
    else
        let target = s:choice_default(curBranch, localBranch, remoteBranch)
    endif
    if empty(target)
        echo 'canceled'
        return ''
    endif

    echo ZFGitCmd(printf('git checkout "%s"', target))
    if v:shell_error == 0 && index(ZFGitGetAllRemoteBranch(), target) >= 0
        echo ZFGitCmd(printf('git reset --hard "origin/%s"', target))
    endif
    return (v:shell_error == 0 ? target : '')
endfunction

function! s:choice_default(curBranch, localBranch, remoteBranch)
    let localOffset = 1
    let remoteOffset = localOffset + len(a:localBranch)

    let hint = []
    call add(hint, 'choose branch to checkout:')
    call add(hint, '')
    for i in range(len(a:localBranch))
        call add(hint, printf('  %s%2s: %s', (a:localBranch[i] == a:curBranch ? '=>' : '  '), localOffset + i, a:localBranch[i]))
    endfor
    call add(hint, '')
    if !empty(a:remoteBranch)
        for i in range(len(a:remoteBranch))
            call add(hint, printf('    %2s: %s', remoteOffset + i, a:remoteBranch[i]))
        endfor
        call add(hint, '')
    endif
    let choice = inputlist(hint)
    redraw

    if choice >= localOffset && choice < localOffset + len(a:localBranch)
        return a:localBranch[choice - localOffset]
    elseif choice >= remoteOffset && choice < remoteOffset + len(a:remoteBranch)
        return a:remoteBranch[choice - remoteOffset]
    else
        return ''
    endif
endfunction

function! s:choice_ZFVimCmdMenu(curBranch, localBranch, remoteBranch)
    let localOffset = 0
    let remoteOffset = len(a:localBranch) + 1

    for branch in a:localBranch
        call ZF_VimCmdMenuAdd({
                    \   'showKeyHint' : 1,
                    \   'text' : printf('%s %s', (branch == a:curBranch ? '=>' : '  '), branch),
                    \   'ZFGitCheckout_branch' : branch,
                    \ })
    endfor
    if !empty(a:remoteBranch)
        call ZF_VimCmdMenuAdd({
                    \   'text' : '',
                    \   'itemType' : 'hint',
                    \ })
        for branch in a:remoteBranch
            call ZF_VimCmdMenuAdd({
                        \   'showKeyHint' : 1,
                        \   'text' : printf('   %s', branch),
                        \   'ZFGitCheckout_branch' : branch,
                        \ })
        endfor
    endif

    let choice = ZF_VimCmdMenuShow({
                \   'headerText' : 'choose branch to checkout:',
                \ })
    redraw
    return get(choice, 'ZFGitCheckout_branch', '')
endfunction

