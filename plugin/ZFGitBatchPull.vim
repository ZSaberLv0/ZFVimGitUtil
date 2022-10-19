
" option: {
"   'clean' : 0/1, // whether auto clean repo, default: 0
"   'gc' : 0/1, // whether auto perform git gc, default: 1 if clean==1
" }
function! ZFGitBatchPull(...)
    let option = get(a:, 1, {})
    let clean = get(option, 'clean', 0)
    let gc = get(option, 'gc', clean)

    redraw!
    let hint = "[ZFGitBatchPull] try to pull all repos under current dir using default config"
    let hint .= "\n"
    let hint .= "\nif you really know what you are doing,"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo '[ZFGitBatchPull] canceled'
        return
    endif

    redraw! | echo '[ZFGitBatchPull] checking repos under current dir'
    silent! let changes = ZFGitStatus({
                \   'all' : 1,
                \ })
    if empty(changes)
        redraw | echo '[ZFGitBatchPull] no repos'
        return []
    endif

    let pwdSaved = getcwd()
    let pullHint = []

    for path in keys(changes)
        let taskHint = ''
        let taskSuccess = 1
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            if clean
                silent! call ZFGitCleanRun(ZFGitCleanInfo())
            endif
            if gc
                call system('git gc --aggressive')
            endif
            let taskHint = ZFGitPushQuickly('u')
        catch
            let taskHint = printf('%s', v:exception)
            let taskSuccess = 0
        finally
            execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
        endtry
        if !empty(taskHint)
            call add(pullHint, taskHint)
        endif
        if !taskSuccess
            break
        endif
    endfor

    execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
    let pullHintText = join(pullHint, "\n")
    let @t = pullHintText
    redraw!
    echo pullHintText
    return changes
endfunction
command! -nargs=* ZFGitBatchPull :call ZFGitBatchPull(<args>)

