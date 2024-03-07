
function! ZFGitCheckout(branch)
    echo ZFGitCmd(printf('git checkout "%s"', a:branch))
endfunction
command! -nargs=1 -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

