
function! ZFGitBatchPush(...)
    let comment = get(a:, 1)
    let changes = ZFGitStatus()
    if empty(changes)
        redraw | echo '[ZFGitBatchPush] no changes'
        return []
    endif

    let hint = "\n============================================================"
    let hint .= "\n[ZFGitBatchPush] try to push all repos under current dir using default config"
    let hint .= "\n"
    let hint .= "\nif you really know what you are doing,"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw!
        echo '[ZFGitBatchPush] canceled'
        return
    endif

    let pwdSaved = getcwd()
    let pushHint = []

    for path in keys(changes)
        let taskHint = ''
        let taskSuccess = 1
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            let taskHint = ZFGitPushQuickly('!', comment)
        catch
            let taskHint = printf('%s', v:exception)
            let taskSuccess = 0
        finally
            execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
        endtry
        if !empty(taskHint)
            call add(pushHint, taskHint)
        endif
        if !taskSuccess
            break
        endif
    endfor

    execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
    let pushHintText = join(pushHint, "\n")
    let @t = pushHintText
    redraw!
    echo pushHintText
    return changes
endfunction
command! -nargs=* ZFGitBatchPush :call ZFGitBatchPush(<q-args>)

