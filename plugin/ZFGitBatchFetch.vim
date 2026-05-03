
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
    return ZFGitBatchAction({
                \   'listOption' : {
                \       'all' : 1,
                \   },
                \   'actionHint' : '[ZFGitBatchFetch] try to fetch and prune all repos under current dir using default config',
                \   'action' : [
                \       "let taskResult = ZFGitFetch(params['option'])",
                \   ],
                \   'option' : get(a:, 1, {}),
                \ })
endfunction
command! -nargs=* ZFGitBatchFetch :call ZFGitBatchFetch(<args>)

