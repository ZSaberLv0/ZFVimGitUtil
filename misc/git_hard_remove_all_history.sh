#!bash

WORK_DIR=$(cd "$(dirname "$0")"; pwd)
PROJ_PATH=$1
GIT_USER_EMAIL=$2
GIT_USER_NAME=$3
GIT_USER_TOKEN=$4

if test "x$PROJ_PATH" = "x" ; then
    echo "hard remove all git history and branches (except HEAD)"
    echo "usage:"
    echo "  sh git_hard_remove_all_history.sh PROJ_PATH"
    echo "NOTE:"
    echo "  local changes would be discarded"
    echo "  you would loose all history and all branches except HEAD"
    exit 1
fi

if test ! -e "$PROJ_PATH/.git"; then
    echo "not a git repo"
    exit 1
fi

_OLD_DIR=$(pwd)
cd "$PROJ_PATH"

REMOTE_URL=`git remote -v | grep "(push)"`
REMOTE_URL=`echo $REMOTE_URL | sed -e "s/origin[^a-z]*//g"`
REMOTE_URL=`echo $REMOTE_URL | sed -e "s/ *(push)//g"`
REMOTE_URL=`echo $REMOTE_URL | sed -e "s#://#://$GIT_USER_NAME:$GIT_USER_TOKEN@#g"`

BRANCH=`git rev-parse --abbrev-ref HEAD`
if test "x-$BRANCH" = "x-" ; then
    echo "unable to parse git branch"
    exit 1
elif test "x-$BRANCH" = "x-HEAD" ; then
    echo "unable to parse git branch, maybe in detached HEAD?"
    exit 1
fi

git checkout .
git fetch "$REMOTE_URL" +refs/heads/*:refs/remotes/origin/*
git reset --hard origin/$BRANCH
git clean -xdf
git pull "$REMOTE_URL"

_TMP_DIR=_git_hard_remove_all_history_tmp_
mkdir "$_TMP_DIR"
mv .git "$_TMP_DIR/"

_PROJ_DIR=$(pwd)
cd "$_TMP_DIR"
git checkout .
git reset --hard
git clean -xdf

git filter-branch --force --index-filter "git rm --cached --ignore-unmatch *" --prune-empty --tag-name-filter cat -- --all

cd "$_PROJ_DIR"

mv "$_TMP_DIR/.git" ./
rm -rf "$_TMP_DIR"

git add -A
git commit -a -m "cleanup history"
if test "x$GIT_USER_EMAIL" = "x" || test "x$GIT_USER_NAME" = "x" || test "x$GIT_USER_TOKEN" = "x" ; then
    git push --force
else
    git config user.email "$GIT_USER_EMAIL"
    git config user.name "$GIT_USER_NAME"
    git push --force "$REMOTE_URL" HEAD
fi

rm -rf .git/refs/original/
git fetch "$REMOTE_URL" +refs/heads/*:refs/remotes/origin/*
git reflog expire --expire=now --all
git gc --prune=now

cd "$_OLD_DIR"

