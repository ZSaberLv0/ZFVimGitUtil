
" option: {
"   'all' : 0/1, // whether include repo which has no changes, default: 0
"   'filter' : 1/0, // whether apply g:ZFGitRepoFilter
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
    let filter = get(option, 'filter', 0)

    redraw | echo 'checking...'

    let paths = split(glob('**/.git', 1), "\n")
    if empty(paths)
        redraw | echo 'no changes'
        return []
    endif

    let hasChanges = 0
    let changes = {}
    let postFixLen = len('/.git')
    let filters = values(get(g:, 'ZFGitRepoFilter', {}))
    let T_func = type(function('type'))
    for path in paths
        let path = strpart(path, 0, len(path) - postFixLen)
        if empty(path)
            let path = '.'
        endif

        " filter
        if filter
            let pathAbs = fnamemodify(path, ':p')
            let filterFlag = 0
            for T_filter in filters
                if type(T_filter) == T_func
                    let filterFlag = T_filter(pathAbs)
                else
                    let filterFlag = (match(pathAbs, T_filter) >= 0) ? 1 : 0
                endif
                if filterFlag
                    break
                endif
            endfor
            if filterFlag
                continue
            endif
        endif

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
command! -nargs=0 -bang ZFGitStatus :call ZFGitStatus(<q-bang> == '!' ? {} : {'filter':0})

