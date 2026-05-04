
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
"     },
"   },
" }
function! ZFGitBatchPull(...)
    return ZFGitBatchAction({
                \   'listOption' : {
                \       'all' : 1,
                \   },
                \   'actionHint' : '[ZFGitBatchPull] try to pull all repos under current dir using default config',
                \   'action' : 'ZFGitBatchPullImpl',
                \   'option' : get(a:, 1, {}),
                \ })
endfunction
function! ZFGitBatchPullImpl(path, params, changes)
    let clean = get(a:params['option'], 'clean', 0)
    let gc = get(a:params['option'], 'gc', clean)
    if clean
        silent! call ZFGitCleanRun(ZFGitCleanInfo())
    endif
    if gc
        call ZFGitCmd('git gc --aggressive')
    endif
    return ZFGitPushQuickly({
                \   'mode' : 'u',
                \ })
endfunction
command! -nargs=* ZFGitBatchPull :call ZFGitBatchPull(<args>)

