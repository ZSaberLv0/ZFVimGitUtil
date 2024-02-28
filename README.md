
some git util for vim

if you like my work, [check here](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim) for a list of my vim plugins,
or [buy me a coffee](https://github.com/ZSaberLv0/ZSaberLv0)


# Install

use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager is recommended

```
Plugin 'ZSaberLv0/ZFVimGitUtil'
```


# Main Feature

* `:ZFGitPushQuickly[!] [comment]`

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

    * only http(s) repo is directly supported: `http(s)://user(:pwd)@server.xx(:port)/path`
    * ssh repo is not directly supported: `(ssh://)user@server:/path`
    * to support ssh repo:
        1. on YourClient: `ssh-keygen`
        1. on YourClient: `ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 YourServerUserName@YourServerDomain`
        1. make sure it works before actually use quick push:

            `git fetch --all`, if fetch success without password required, then you are done

* `:ZFGitBatchPull`

    find and go through all git repo under cwd,
    and try to pull

* `:ZFGitBatchPush [comment]`

    find and go through all git repo under cwd,
    and try to push

* `:ZFGitClean`

    fill a temp file with untracked and ignored files,
    save the temp file to remove all of these files

* `:ZFGitStatus`

    find and go through all git repo under cwd,
    echo its changes by `git status -s`

* `:ZFGitHardRemoveAllHistory`

    like the name, use with caution

* **NOTE**: github would no longer support plain password push method
    (`https://YourName:YourPlainPassword@github.com/xxx`),
    you must use [access token](https://github.com/settings/tokens) for now,
    [see here](https://github.blog/2020-12-15-token-authentication-requirements-for-git-operations) for more info,
    and see below for how to use the access token for short


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

* `ZFGitPwdSet(git_remoteurl, git_user_name, git_user_pwd)`

    update the password stored by `ZFGitPushQuickly`,
    set empty `git_user_pwd` to remove saved password

* `ZFGitPrepare(options)`

    prepare necessary git info

    options:

    * `module` : module name, ZFGit by default
    * `needPwd` : whether need pwd, false by default
    * `confirm` : whether need confirm, true by default
    * `extraInfo` : extra info when confirm, empty by default
    * `extraChoice` : extra choice options

        ```
        {
            'key1' : 'text1',
            'key2' : 'text2',
        }
        ```

    return:

    * `choice` : y/extraChoice
    * `git_remoteurl`
    * `git_user_email`
    * `git_user_name`
    * `git_user_pwd`

* `ZFGitGetRemote()`

    parse git remote url

* `ZFGitGetInfo()`

    return current git config (see `ZFGitPushQuickly` above)

    return:

    * `git_remoteurl`
    * `git_user_email`
    * `git_user_name`
    * `git_user_pwd`

