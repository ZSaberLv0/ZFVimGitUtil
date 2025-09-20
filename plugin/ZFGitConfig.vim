
function! ZFGitConfig()
    for config in g:zf_git_extra_config
        call ZFGitCmd(config)
        call ZFGitCmd('git submodule foreach --recursive ' . config)
    endfor
endfunction

command! -nargs=0 ZFGitConfig :call ZFGitConfig()

