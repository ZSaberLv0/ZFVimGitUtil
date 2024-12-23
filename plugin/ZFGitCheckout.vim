
command! -nargs=? -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

" option: {
"   'force' : 0/1, // whether try to perform `git reset --hard origin/<branch>`
"                  // valid only if remote branch exists
" }
"
" return: branch name if success, or empty if fail
function! ZFGitCheckout(branch)
    if !empty(a:branch) && stridx(a:branch, '*') < 0
        let targetInfo = ZFGitBranchPick(a:branch, {
                    \   'title' : 'choose branch to checkout:',
                    \ })
        if targetInfo['exist']
                    \ || filereadable(a:branch)
                    \ || isdirectory(a:branch)
                    \ || !empty(split(ZFGitCmd(printf('git status -s "%s"', a:branch)), "\n"))
            echo s:checkout(a:branch)
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

    let targetInfo = ZFGitBranchPick(a:branch, {
                \   'title' : 'choose branch to checkout:',
                \ })
    if empty(targetInfo['branch'])
        echo 'canceled'
        return ''
    endif

    echo s:checkout(targetInfo['branch'])
    return (v:shell_error == 0 ? targetInfo['branch'] : '')
endfunction

function! s:checkout(branch)
    let allLocal = ZFGitGetAllLocalBranch()
    let allRemote = ZFGitGetAllRemoteBranch()
    if index(allLocal, a:branch) < 0 && index(allRemote, a:branch) >= 0
        return ZFGitCmd(printf('git checkout -b "%s" "origin/%s"', a:branch, a:branch))
    else
        return ZFGitCmd(printf('git checkout "%s"', a:branch))
    endif
endfunction

