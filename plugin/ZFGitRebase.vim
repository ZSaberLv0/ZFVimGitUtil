
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

    let branch = targetInfo['branch']
    if index(ZFGitGetAllLocalBranch(), branch) < 0
        let branch = 'origin/' . branch
    endif

    execute ':Git rebase -i ' . substitute(branch, ' ', '\\ ', 'g')
endfunction
command! -nargs=* -complete=customlist,ZFGitCmdComplete_branch ZFGitRebase :call ZFGitRebase(<q-args>)

function! ZFGitRebaseContinue()
    if !exists(':Git')
        echo 'ZFGitRebase depends on tpope/vim-fugitive'
        return
    endif
    execute ':Git rebase --continue'
endfunction
command! -nargs=0 ZFGitRebaseContinue :call ZFGitRebaseContinue()

function! ZFGitRebaseAbort()
    if !exists(':Git')
        echo 'ZFGitRebase depends on tpope/vim-fugitive'
        return
    endif
    execute ':Git rebase --abort'
endfunction
command! -nargs=0 ZFGitRebaseAbort :call ZFGitRebaseAbort()

