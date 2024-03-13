
command! -nargs=? -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

function! ZFGitCheckout(branch)
    if !empty(a:branch) && stridx(a:branch, '*') < 0
        echo ZFGitCmd(printf('git checkout "%s"', a:branch))
        return
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

    let remoteBranch = ZFGitGetAllRemoteBranch()
    let i = len(remoteBranch) - 1
    while i >= 0
        if match(remoteBranch[i], pattern) < 0
                    \ || index(localBranch, remoteBranch[i]) >= 0
            call remove(remoteBranch, i)
        endif
        let i -= 1
    endwhile

    let target = s:choice_default(curBranch, localBranch, remoteBranch)
    if empty(target)
        echo 'canceled'
    else
        echo ZFGitCmd(printf('git checkout "%s"', target))
    endif
endfunction

function! s:choice_default(curBranch, localBranch, remoteBranch)
    let localCount = len(a:localBranch)
    let remoteCount = len(a:remoteBranch)

    let hint = []
    call add(hint, 'choose branch to checkout:')
    call add(hint, '')
    for i in range(localCount)
        call add(hint, printf('  %s%2s: %s', (a:localBranch[i] == a:curBranch ? '=>' : '  '), i + 1, a:localBranch[i]))
    endfor
    call add(hint, '')
    for i in range(remoteCount)
        call add(hint, printf('    %2s: %s', localCount + i + 1, a:remoteBranch[i]))
    endfor
    call add(hint, '')
    let choice = inputlist(hint)
    let choice = choice - 1

    redraw
    if choice < 0 || choice >= localCount + remoteCount
        return ''
    endif
    if choice < localCount
        return a:localBranch[choice]
    else
        return a:remoteBranch[choice - localCount]
    endif
endfunction

