
function! ZFGitCheckout(branch)
    echo ZFGitCmd('git checkout ' . a:branch)
endfunction
command! -nargs=1 -complete=customlist,ZFGitCmdComplete_branch ZFGitCheckout :call ZFGitCheckout(<q-args>)

