
" ============================================================
" see:
"   https://github.com/git/git/tree/master/po
" ============================================================

"Your branch is ahead of '%s' by %d commit.\n"
"Your branch is ahead of '%s' by %d commits.\n"
function! ZF_GitMsgFormat_containLocalCommits()
    return [
                \   'Your branch is ahead of ',
                \   '您的分支领先 ',
                \ ]
endfunction

"ambiguous argument '%s': unknown revision or path not in the working tree.\n"
"Use '--' to separate paths from revisions, like this:\n"
"'git <command> [<revision>...] -- [<file>...]'"
function! ZF_GitMsgFormat_noRemoteBranch()
    return [
                \   'unknown revision or path not in the working tree',
                \   '未知的版本或路径不存在于工作区中',
                \ ]
endfunction

