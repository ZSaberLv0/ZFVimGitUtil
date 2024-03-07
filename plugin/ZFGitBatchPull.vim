
" option: {
"   'clean' : 0/1, // whether auto clean repo, default: 0
"   'gc' : 0/1, // whether auto perform git gc, default: 1 if clean==1
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
function! ZFGitBatchPull(...)
    let option = get(a:, 1, {})
    let clean = get(option, 'clean', 0)
    let gc = get(option, 'gc', clean)

    redraw
    let hint = "[ZFGitBatchPull] try to pull all repos under current dir using default config"
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
        try
            execute 'cd ' . substitute(path, ' ', '\\ ', 'g')
            if clean
                silent! call ZFGitCleanRun(ZFGitCleanInfo())
            endif
            if gc
                call ZFGitCmd('git gc --aggressive')
            endif
            let taskResult = ZFGitPushQuickly({
                        \   'mode' : 'u',
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
    let taskHintText = join(taskHint, "\n")
    let @t = taskHintText
    redraw
    echo taskHintText
    return {
                \   'exitCode' : (exitCode == '' ? '0' : exitCode),
                \   'task' : task,
                \ }
endfunction
command! -nargs=* ZFGitBatchPull :call ZFGitBatchPull(<args>)

