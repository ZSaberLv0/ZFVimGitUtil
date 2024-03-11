
function! ZFGitCheckout(branch)
    if !empty(a:branch) && stridx(a:branch, '*') < 0
        echo ZFGitCmd(printf('git checkout "%s"', a:branch))
        return
    endif

    let pattern = substitute(a:branch, '\.', '\\\.', 'g')
    let pattern = substitute(pattern, '\*', '\.\*', 'g')

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

    let candidateHint = ['choose branch to checkout:']
    for i in range(len(candidate))
        call add(candidateHint, printf('    %s: %s', i + 1, candidate[i]))
    endfor
    let choice = inputlist(candidateHint)

    redraw
    if choice <= 0 || choice >= len(candidate)
        echo 'canceled'
        return
    endif

    echo ZFGitCmd(printf('git checkout "%s"', candidate[choice]))
endfunction
command! -nargs=? -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

