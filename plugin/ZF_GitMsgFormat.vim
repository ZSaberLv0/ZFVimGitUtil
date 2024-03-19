
" ============================================================
" see:
"   https://github.com/git/git/tree/master/po
" ============================================================

"## master...origin/master [ahead 1]"
function! ZF_GitMsgFormat_containLocalCommits()
    " \[ahead [0-9]+\]($|\n)
    return [
                \   '\[ahead [0-9]\+\]\($\|\n\)',
                \ ]
endfunction

function! ZF_GitMsgFormat_conflictPattern()
    " <<<<<<< Updated upstream
    " content A
    " =======
    " content B
    " >>>>>>> Stashed changes
    "
    " ^<<<<<<<+ .*$|^=======+$|^>>>>>>>+ .*$
    return '^<<<<<<<\+ .*$\|^=======\+$\|^>>>>>>>\+ .*$'
endfunction

