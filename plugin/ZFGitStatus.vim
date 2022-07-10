
function! ZF_GitStatus()
    redraw | echo '[ZFGitStatus] checking'

    let paths = split(glob('**/.git', 1), "\n")
    if empty(paths)
        redraw | echo '[ZFGitStatus] no changes'
        return []
    endif

    let changes = {}
    let postFixLen = len('/.git')
    for path in paths
        let path = strpart(path, 0, len(path) - postFixLen)
        if empty(path)
            let path = '.'
        endif

        let change = split(system('cd "' . path . '"&& git status -s'), "\n")
        if !empty(change)
            let changes[path] = change
        endif
    endfor

    if empty(changes)
        redraw | echo '[ZFGitStatus] no changes'
        return []
    endif

    let hint = "[ZFGitStatus] changes:\n"
    for path in sort(keys(changes), 1)
        let hint .= "\n  " . path . "/\n"
        for item in changes[path]
            let hint .= '      ' . item . "\n"
        endfor
    endfor
    redraw | echo hint
    let @t = hint
    return changes
endfunction
command! -nargs=0 ZFGitStatus :call ZF_GitStatus()

