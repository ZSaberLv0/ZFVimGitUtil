
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
    return ZFGitBatchAction({
                \   'showRepoChanges' : '1',
                \   'actionHint' : '[ZFGitBatchPush] try to push all repos under current dir using default config',
                \   'action' : 'ZFGitBatchPushImpl',
                \   'option' : get(a:, 1, {}),
                \ })
endfunction
function! ZFGitBatchPushImpl(path, params, changes)
    return ZFGitPushQuickly({
                \   'mode' : '!',
                \   'comment' : get(a:params['option'], 'comment', ''),
                \ })
endfunction
command! -nargs=* ZFGitBatchPush :call ZFGitBatchPush({'comment':<q-args>})

