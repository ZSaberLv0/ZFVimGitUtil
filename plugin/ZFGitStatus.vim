
" option: {
"   'all' : 0/1, // whether include repo which has no changes, default: 0
"   'filter' : 1/0, // whether apply g:ZFGitRepoFilter
"   'followSymlink' : 1/0, // whether follow symlink
" }
"
" return: {
"   'repo path' : [
"     'U xxx',
"     'D xxx',
"   ],
" }
function! ZFGitStatus(...)
    let option = get(a:, 1, {})
    let all = get(option, 'all', 0)
    let filter = get(option, 'filter', 1)

    redraw | echo 'checking...'

    let paths = ZFGitRepoList(option)
    if empty(paths)
        redraw | echo 'no changes'
        return []
    endif

    let hasChanges = 0
    let changes = {}
    for path in paths
        let change = split(ZFGitCmd(printf('cd "%s" && git status -s', path)), "\n")
        if all || !empty(change)
            if !empty(change)
                let hasChanges = 1
            endif
            let changes[path] = change
        endif
    endfor

    if !hasChanges && !all
        redraw | echo 'no changes'
        return []
    endif

    let hint = "[ZFGitStatus] changes:\n"
    for path in sort(keys(changes), 1)
        if empty(changes[path])
            continue
        endif

        let hint .= "\n  " . path . "/\n"
        for item in changes[path]
            let hint .= '      ' . item . "\n"
        endfor
    endfor
    redraw | echo hint
    let @t = hint
    return changes
endfunction
command! -nargs=0 -bang ZFGitStatus :call ZFGitStatus(<q-bang> == '!' ? {'filter' : 0} : {})

