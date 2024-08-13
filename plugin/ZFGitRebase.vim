
function! ZFGitRebase(baseBranch)
    if !exists(':Git')
        echo 'ZFGitRebase depends on tpope/vim-fugitive'
        return
    endif

    let targetInfo = ZFGitBranchPick(a:baseBranch, {
                \   'title' : 'choose branch to rebase to:',
                \ })
    if empty(targetInfo['branch'])
        echo 'canceled'
        return
    endif

    execute ':Git rebase -i ' . substitute(targetInfo['branch'], ' ', '\\ ', 'g')
endfunction
command! -nargs=* ZFGitRebase :call ZFGitRebase(<q-args>)

