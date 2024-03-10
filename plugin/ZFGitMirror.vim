
" change global git mirror
"
" option: {
"   'mirrorFrom' : 'https://github.com',
"   'mirrorTo' : 'https://some_mirror.com',
"   'reset' : 0/1, // whether to reset to no mirror when input mirror is empty
"   'local' : 0/1, // whether local mode
" }
"
" return: {
"   // new state
"   'mirrorFrom' : 'https://github.com',
"   'mirrorTo' : 'https://some_mirror.com',
" }
function! ZFGitMirror(option)
    let mirrorFrom = get(a:option, 'mirrorFrom', '')
    let mirrorTo = get(a:option, 'mirrorTo', '')
    let reset = get(a:option, 'reset', 0)
    let local = get(a:option, 'local', 0)

    let globalFix = (!local ? '--global' : '')

    " url.https://xxx.com/.insteadof https://
    " url\."?(.*?)"?\.insteadof (.*)
    let mirrorState = ZFGitCmd(printf('git config %s --get-regexp "url.*insteadOf"', globalFix))
    let mirrorFromOld = substitute(
                \ mirrorState,
                \ 'url\."\=\(.\{-}\)"\=\.insteadof \(.*\)',
                \ '\1',
                \ '')
    if mirrorFromOld == mirrorState
        let mirrorFromOld = ''
    endif
    let mirrorToOld = substitute(
                \ mirrorState,
                \ 'url\."\=\(.\{-}\)"\=\.insteadof \(.*\)',
                \ '\1',
                \ '')
    if mirrorToOld == mirrorState
        let mirrorToOld = ''
    endif

    if empty(mirrorFrom) || empty(mirrorTo)
        if reset
            if !empty(mirrorFromOld)
                call ZFGitCmd(printf('git config %s --remove-section url."%s"', globalFix, mirrorFromOld))
            endif
            let mirrorFromNew = ''
            let mirrorToNew = ''
            echo 'git mirror cleared'
        else
            let mirrorFromNew = mirrorFromOld
            let mirrorToNew = mirrorToOld
            if empty(mirrorFromNew) || empty(mirrorToNew)
                echo 'git mirror: NONE'
            else
                echo printf('git mirror: %s => %s', mirrorFromNew, mirrorToNew)
            endif
        endif
    else
        if !empty(mirrorFromOld)
            call ZFGitCmd(printf('git config %s --remove-section url."%s"', globalFix, mirrorFromOld))
        endif
        call ZFGitCmd(printf('git config %s url."%s".insteadOf "%s"', globalFix, mirrorTo, mirrorFrom))
        let mirrorFromNew = mirrorFrom
        let mirrorToNew = mirrorTo
        echo printf('git mirror: %s => %s', mirrorFromNew, mirrorToNew)
    endif

    return {
                \   'mirrorFrom' : mirrorFromNew,
                \   'mirrorTo' : mirrorToNew,
                \ }
endfunction

