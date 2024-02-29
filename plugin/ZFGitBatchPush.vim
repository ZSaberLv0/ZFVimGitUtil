
" option: {
"   'comment' : 'push comment',
" }
"
" return: {
"   'exitCode' : '',
"       // 0: success
"       // 'ZF_CANCELED': canceled
"       // 'ZF_NO_REPO': no repo
"       // other: error
"   'task' : {
"     'repo path' : {
"       'exitCode' : '', // result of ZFGitPushQuickly
"       'output' : '',
"       'changes' : [ // changes of ZFGitStatus
"         'U xxx',
"         'D xxx',
"       ],
"     },
"   },
" }
function! ZFGitBatchPush(...)
    let option = get(a:, 1, {})
    let comment = get(option, 'comment', '')
    let changes = ZFGitStatus()
    if empty(changes)
        redraw | echo 'no changes'
        return {
                    \   'exitCode' : 'ZF_NO_REPO',
                    \   'task' : {},
                    \ }
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
        echo 'canceled'
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'task' : {},
                    \ }
    endif

    let pwdSaved = getcwd()
    let taskHint = []

    let error = ''
    let task = {}

    for path in keys(changes)
        let taskResult = {}
        let taskSuccess = 1
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            let taskResult = ZFGitPushQuickly({
                        \   'mode' : '!',
                        \   'comment' : comment,
                        \ })
        catch
            let taskResult = {
                        \   'exitCode' : 'ZF_ERROR',
                        \   'output' : printf('%s', v:exception),
                        \ }
            let taskSuccess = 0
        finally
            execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
        endtry
        if !empty(taskResult)
            call add(taskHint, taskResult['output'])
        endif
        let taskResult['changes'] = changes['path']
        let task[path] = taskResult
        if !taskSuccess
            if exitCode != ''
                let exitCode .= '_'
            endif
            let exitCode .= taskResult['exitCode']
            break
        endif
    endfor

    execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
    let taskHintText = join(taskHint, "\n")
    let @t = taskHintText
    redraw!
    echo taskHintText
    return {
                \   'exitCode' : (error == '' ? '0' : error),
                \   'task' : task,
                \ }
endfunction
command! -nargs=* ZFGitBatchPush :call ZFGitBatchPush({'comment':<q-args>})

