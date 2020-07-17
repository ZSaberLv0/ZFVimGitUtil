
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

function! ZF_GitMsgFormat_conflict()
    return [
                \   '^CONFLICT (',
                \   '^冲突（',
                \ ]
endfunction

function! s:add(exist, ret, pattern)
    let key = a:pattern[0] . ':' . a:pattern[1]
    if !exists('a:exist[key]')
        let a:exist[key] = 1
        call add(a:ret, a:pattern)
    endif
endfunction
function! ZF_GitMsgFormat_conflictFileMatcher()
    let ret = []

    for pattern in [
                \   'both deleted:',
                \   '双方删除：',
                \   'added by us:',
                \   '由我们添加：',
                \   'deleted by them:',
                \   '由他们删除：',
                \   'added by them:',
                \   '由他们添加：',
                \   'deleted by us:',
                \   '由我们删除：',
                \   'both added:',
                \   '双方添加：',
                \   'both modified:',
                \   '双方修改：',
                \   'new file:',
                \   '新文件：',
                \   'copied:',
                \   '拷贝：',
                \   'deleted:',
                \   '删除：',
                \   'modified:',
                \   '修改：',
                \   'renamed:',
                \   '重命名：',
                \   'typechange:',
                \   '类型变更：',
                \   'unknown:',
                \   '未知：',
                \   'unmerged:',
                \   '未合并：',
                \ ]
        " ^[ \t]*xxx[ \t]*(.*?)[ \t]*$
        call add(ret, ['^[ \t]*' . pattern . '[ \t]*\(.\{-}\)[ \t]*$', '\1'])
    endfor

    return ret
endfunction

