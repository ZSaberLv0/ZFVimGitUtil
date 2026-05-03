
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
"     },
"   },
" }
function! ZFGitBatchPush(...)
    let hint = "[ZFGitBatchPush] try to push all repos under current dir using default config"
    let hint .= "\n"
    let hint .= "\nif you really know what you are doing,"
    let hint .= "\nenter `got it` to continue: "
    return ZFGitBatchAction({
                \   'listOption' : {
                \       'all' : 1,
                \   },
                \   'actionHint' : hint,
                \   'action' : 'ZFGitBatchPushImpl',
                \   'option' : get(a:, 1, {}),
                \ })
endfunction
function! ZFGitBatchPushImpl(path, params)
    return ZFGitPushQuickly({
                \   'mode' : '!',
                \   'comment' : get(a:params['option'], 'comment', ''),
                \ })
endfunction
command! -nargs=* ZFGitBatchPush :call ZFGitBatchPush({'comment':<q-args>})

