
" name can be:
" * exact branch name
" * wildcard match (`release/*`)
" * empty string (to pick from all branches)
"
" option: {
"   'title' : 'choose target branch:',
"   'local' : 1/0,
"   'remote' : 1/0,
" }
"
" return: {
"   'exist' : 0/1, // whether branch exists
"   'branch' : 'full branch name, or empty if canceled',
" }
function! ZFGitBranchPick(branch, ...)
    let option = get(a:, 1, {})
    let title = get(option, 'title', 'choose target branch:')
    let checkLocal = get(option, 'local', 1)
    let checkRemote = get(option, 'remote', 1)

    if !empty(a:branch) && stridx(a:branch, '*') < 0
        if checkLocal && checkRemote
            let allBranch = ZFGitGetAllBranch()
        elseif checkLocal
            let allBranch = ZFGitGetAllLocalBranch()
        elseif checkRemote
            let allBranch = ZFGitGetAllRemoteBranch()
        else
            let allBranch = []
        endif
        if index(allBranch, a:branch) >= 0
            return {
                        \   'exist' : 1,
                        \   'branch' : a:branch,
                        \ }
        else
            return {
                        \   'exist' : 0,
                        \   'branch' : a:branch,
                        \ }
        endif
    endif

    let pattern = substitute(a:branch, '\.', '\\\.', 'g')
    let pattern = substitute(pattern, '\*', '\.\*', 'g')
    let curBranch = ZFGitGetCurBranch()

    let localBranch = checkLocal ? ZFGitGetAllLocalBranch() : []
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

    let remoteBranch = checkRemote ? ZFGitGetAllRemoteBranch() : []
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
        let target = s:choice_ZFVimCmdMenu(title, curBranch, localBranch, remoteBranch)
    else
        let target = s:choice_default(title, curBranch, localBranch, remoteBranch)
    endif
    return {
                \   'exist' : !empty(target),
                \   'branch' : target,
                \ }
endfunction

function! s:choice_default(title, curBranch, localBranch, remoteBranch)
    let localOffset = 1
    let remoteOffset = localOffset + len(a:localBranch)

    let hint = []
    call add(hint, a:title)
    call add(hint, '')
    for i in range(len(a:localBranch))
        call add(hint, printf('  %s%2s: %s', (a:localBranch[i] == a:curBranch ? '=>' : '  '), localOffset + i, a:localBranch[i]))
    endfor
    if !empty(a:localBranch)
        call add(hint, '')
    endif
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

function! s:choice_ZFVimCmdMenu(title, curBranch, localBranch, remoteBranch)
    let localOffset = 0
    let remoteOffset = len(a:localBranch) + 1

    for branch in a:localBranch
        call ZF_VimCmdMenuAdd({
                    \   'showKeyHint' : 1,
                    \   'text' : printf('%s %s', (branch == a:curBranch ? '=>' : '  '), branch),
                    \   'ZFGitBranchPick_branch' : branch,
                    \ })
    endfor
    if !empty(a:remoteBranch)
        if !empty(a:localBranch)
            call ZF_VimCmdMenuAdd({
                        \   'text' : '',
                        \   'itemType' : 'hint',
                        \ })
        endif
        for branch in a:remoteBranch
            call ZF_VimCmdMenuAdd({
                        \   'showKeyHint' : 1,
                        \   'text' : printf('   %s', branch),
                        \   'ZFGitBranchPick_branch' : branch,
                        \ })
        endfor
    endif

    let choice = ZF_VimCmdMenuShow({
                \   'headerText' : a:title,
                \ })
    redraw
    return get(choice, 'ZFGitBranchPick_branch', '')
endfunction

