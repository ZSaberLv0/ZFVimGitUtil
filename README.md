
some git util for vim

if you like my work, [check here](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim) for a list of my vim plugins


# Install

use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager is recommended

```
Plugin 'ZSaberLv0/ZFVimGitUtil'
```


# Main Feature

* `ZFGitPushQuickly`

    "stash > pull  > unstash > commit > push" quickly

    usage:

    * `cd` to a git repo
    * `:ZFGitPushQuickly[!] [commit message]`
    * show commit info before actually perform, unless the `<bang>` token `!` is set
    * if `[commit message]` omitted, `g:ZFGitPushQuickly_defaultMsg` would be used

    features:

    * all changed and added files would be committed
    * if conflicts, push would abort, and conflicted files would be opened automatically
    * user name/email/password would be saved temporarily, stop input them repeatly like a nerd

    note:

    * we only support git remote with this syntax: `http(s)://user(:pwd)@server.xx(:port)/path`
    * typical case that not directly supported: `(ssh://)user@server:/path`
    * to support ssh repo:
        1. on YourClient: `ssh-keygen`
        1. on YourClient: `ssh-copy-id -i ~/.ssh/id_rsa.pub YourServerUserName@YourServerDomain`

* `ZFGitClean`

    fill a temp file with untracked and ignored files,
    save the temp file to remove all of these files

* `ZFGitHardRemoveAllHistory`

    like the name, use with caution


# Configs

* to make things more convenient and more safe,
    it's recommended to setup [access token](https://github.com/settings/tokens)

    * private repos are also supported, but your [access token](https://github.com/settings/tokens)
        must have push permission to your private repos,
        otherwise, this confusing error message may occur:

        ```
        remote: Repository not found.
        fatal: repository 'https://YourName@github.com/YourName/YourRepo/' not found
        ```

        * for public repos, check `Access public repositories` would be fine
        * for private repos, you must check `Full control of private repositories`

* we are trying hard to make `ZFGitPushQuickly` more quickly,
    the git user name/email/password are detected automatically with these order:

    1. your custom setting

        ```
        let g:zf_git = [
                \   {
                \     'repo' : 'https://github.com/YourName/YourRepo', " match by string compare
                \     'repo_regexp' : 'github\.com', " match by regexp `match()`
                \
                \     'git_user_email' : '',
                \     'git_user_name' : '',
                \     'git_user_pwd' : '', " optional
                \   },
                \ ]
        ```

    1. `git config user.name` / `git config user.email` to check from local repo
    1. your global custom setting

        ```
        let g:zf_git_user_email = ''
        let g:zf_git_user_name = ''
        let g:zf_git_user_pwd = '' " optional
        ```

    1. `git config --global user.name` / `git config --global user.email` to check from git global setting

* the `git_user_pwd` mentioned above,
    can be your git password,
    or `access token` mentioned above

* the email and user name would be saved to `git config` of local repo,
    the password would be saved temporarily until vim exit

* by default, we would apply some git configs to local repo config:

    ```
    let g:zf_git_extra_config = [
            \   'git config core.filemode false',
            \   'git config core.autocrlf false',
            \   'git config core.safecrlf true',
            \ ]
    ```


# Functions

* `ZF_GitPwdSet(git_remoteurl, git_user_name, git_user_pwd)`

    update the password stored by `ZFGitPushQuickly`,
    set empty `git_user_pwd` to remove saved password

* `ZF_GitPrepare(options)`

    prepare necessary git info

    options:

    * `module` : module name, ZFGit by default
    * `needPwd` : whether need pwd, false by default
    * `confirm` : whether need confirm, true by default
    * `extraInfo` : extra info when confirm, empty by default

    return:
    * `git_remoteurl`
    * `git_user_email`
    * `git_user_name`
    * `git_user_pwd`

* `ZF_GitGetRemote()`

    parse git remote url

* `ZF_GitGetInfo()`

    return current git config (see `ZFGitPushQuickly` above)

    return:
    * `git_remoteurl`
    * `git_user_email`
    * `git_user_name`
    * `git_user_pwd`

* `ZF_GitPushAllQuickly(gitRepoDirs[, msg])`

    push multiple repo

