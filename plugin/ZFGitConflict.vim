
command! -nargs=0 ZFGitConflictOpen :call ZFGitConflictOpen()
function! ZFGitConflictOpen(...)
    let conflictFiles = ZFGitGetAllConflictFiles(get(a:, 1, {}))
    for file in conflictFiles
        execute 'edit ' . substitute(file, ' ', '\\ ', 'g')
    endfor
    if empty(conflictFiles)
        echo 'no conflicts'
    else
        let @/ = ZF_GitMsgFormat_conflictPattern()
        call histadd('/', @/)
        silent! normal! ggnzz
    endif
    return conflictFiles
endfunction

command! -nargs=0 ZFGitConflictResolve :call ZFGitConflictResolve()

" option: {
"   'confirm' : 1/0,
" }
function! ZFGitConflictResolve(...)
    let option = get(a:, 2, {})
    let confirm = get(option, 'confirm', 1)

    let conflictFiles = ZFGitGetAllConflictFiles(get(a:, 1, {}))
    if empty(conflictFiles)
        echo 'no conflicts'
        return conflictFiles
    endif

    if confirm
        let hint = 'mark all conflicts as resolved?'
        for file in conflictFiles
            let hint .= "\n    " . file
        endfor
        let hint .= "\n"
        let hint .= "\nenter `got it` to continue: "
        redraw
        call inputsave()
        let input = input(hint)
        call inputrestore()
        redraw
        if input != 'got it'
            echo 'canceled'
            return []
        endif
    endif

    for file in conflictFiles
        let result = ZFGitCmd(printf('git add "%s"', file))
        if v:shell_error != 0
            echo result
        endif
    endfor
    echo 'conflicts mark as resolved'
    return conflictFiles
endfunction

