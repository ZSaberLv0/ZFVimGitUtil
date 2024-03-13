
function! ZFGitCheckout(branch)
    if !empty(a:branch) && stridx(a:branch, '*') < 0
        echo ZFGitCmd(printf('git checkout "%s"', a:branch))
        return
    endif

    let pattern = substitute(a:branch, '\.', '\\\.', 'g')
    let pattern = substitute(pattern, '\*', '\.\*', 'g')

    let curBranch = ZFGitGetCurBranch()
    let allBranch = ZFGitGetAllBranch()
    let candidate = []
    for branch in allBranch
        if match(branch, pattern) >= 0
            call add(candidate, branch)
        endif
    endfor
    if empty(candidate)
        let candidate = allBranch
    endif

    let candidateHint = []
    call add(candidateHint, 'choose branch to checkout:')
    call add(candidateHint, '')
    for i in range(len(candidate))
        call add(candidateHint, printf('  %s%2s: %s', (candidate[i] == curBranch ? '=>' : '  '), i + 1, candidate[i]))
    endfor
    call add(candidateHint, '')
    let choice = inputlist(candidateHint)
    let choice = choice - 1

    redraw
    if choice < 0 || choice >= len(candidate)
        echo 'canceled'
        return
    endif

    " echo ZFGitCmd(printf('git checkout "%s"', candidate[choice]))
endfunction
command! -nargs=? -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

