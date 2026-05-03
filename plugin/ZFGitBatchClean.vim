
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
"     },
"   },
" }
function! ZFGitBatchClean(...)
    return ZFGitBatchAction({
                \   'listOption' : {
                \       'filter' : 0,
                \   },
                \   'actionHint' : '[ZFGitBatchClean] try to clean all repos local changes under current dir, can not undo',
                \   'action' : [
                \       "let taskResult = ZFGitClean(params['option'])",
                \   ],
                \   'option' : get(a:, 1, {}),
                \ })
endfunction
command! -bang ZFGitBatchClean :call ZFGitBatchClean({'backup':<q-bang>!='!'})

