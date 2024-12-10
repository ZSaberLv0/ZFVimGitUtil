
" option: {
"   ... // params passed to ZFGitClean
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
"       'exitCode' : '', // result of ZFGitCleanRun
"       'output' : '',
"       'changes' : [ // changes of ZFGitStatus
"         'U xxx',
"         'D xxx',
"       ],
"     },
"   },
" }
function! ZFGitBatchClean(...)
    let option = get(a:, 1, {})
    let cleanAllSubmodule = get(option, 'cleanAllSubmodule', 1)
    let changes = ZFGitStatus({
                \   'filter' : 0,
                \ })
    if empty(changes)
        redraw | echo 'no changes'
        return {
                    \   'exitCode' : 'ZF_NO_REPO',
                    \   'task' : {},
                    \ }
    endif

    let hint = "\n============================================================"
    let hint .= "\n[ZFGitBatchClean] try to clean all repos' local changes under current dir, can not undo"
    let hint .= "\n"
    let hint .= "\nif you really know what you are doing,"
    let hint .= "\nenter `got it` to continue: "
    call inputsave()
    let input = input(hint)
    call inputrestore()
    if input != 'got it'
        redraw
        echo 'canceled'
        return {
                    \   'exitCode' : 'ZF_CANCELED',
                    \   'task' : {},
                    \ }
    endif

    let pwdSaved = getcwd()
    let taskHint = []

    let exitCode = ''
    let task = {}

    for path in keys(changes)
        let taskResult = {}
        let taskSuccess = 1
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            let taskResult = ZFGitClean(option)
        catch
            let taskResult = {
                        \   'exitCode' : 'ZF_ERROR',
                        \   'output' : printf('%s', v:exception),
                        \ }
            let taskSuccess = 0
        finally
            execute 'cd ' . substitute(pwdSaved, ' ', '\\ ', 'g')
        endtry
        if !empty(get(taskResult, 'output', ''))
            call add(taskHint, taskResult['output'])
        endif
        let taskResult['changes'] = changes[path]
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
    call insert(taskHint, "local changes cleaned:\n", 0)
    let taskHintText = join(taskHint, "\n")
    let @t = taskHintText
    redraw
    echo taskHintText
    return {
                \   'exitCode' : (exitCode == '' ? '0' : exitCode),
                \   'task' : task,
                \ }
endfunction
command! -bang ZFGitBatchClean :call ZFGitBatchClean({'backup':<q-bang>!='!'})

