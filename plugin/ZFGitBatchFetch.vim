
" option: {
"   ... // params passed to ZFGitFetch
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
"     },
"   },
" }
function! ZFGitBatchFetch(...)
    let option = get(a:, 1, {})

    redraw
    let hint = "[ZFGitBatchFetch] try to fetch and prune all repos under current dir using default config"
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

    redraw | echo 'checking repos under current dir...'
    silent! let changes = ZFGitStatus({
                \   'all' : 1,
                \ })
    if empty(changes)
        redraw | echo 'no repos'
        return {
                    \   'exitCode' : 'ZF_NO_REPO',
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
        redraw | echo 'fetching... ' . path
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            silent let taskResult = ZFGitFetch(option)
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
    redraw
    echo taskHintText
    return {
                \   'exitCode' : (exitCode == '' ? '0' : exitCode),
                \   'task' : task,
                \ }
endfunction
command! -nargs=* ZFGitBatchFetch :call ZFGitBatchFetch(<args>)

