#!/usr/bin/env bash
set -e

if [[ "${DEBUG}" -eq "true" ]]; then
    set -x
fi

git config --global --add safe.directory /github/workspace

GIT_USERNAME=${INPUT_GIT_USERNAME:-${GIT_USERNAME:-"git"}}
REMOTE=${INPUT_REMOTE:-"$*"}
REMOTE_NAME=${INPUT_REMOTE_NAME:-"mirror"}
GIT_SSH_PRIVATE_KEY=${INPUT_GIT_SSH_PRIVATE_KEY}
GIT_SSH_PUBLIC_KEY=${INPUT_GIT_SSH_PUBLIC_KEY}
GIT_PUSH_ARGS=${INPUT_GIT_PUSH_ARGS:-"--tags --force --prune"}
GIT_SSH_NO_VERIFY_HOST=${INPUT_GIT_SSH_NO_VERIFY_HOST}
GIT_SSH_KNOWN_HOSTS=${INPUT_GIT_SSH_KNOWN_HOSTS}
HAS_CHECKED_OUT="$(git rev-parse --is-inside-work-tree 2>/dev/null || /bin/true)"
SSH_DIR="$(realpath ~)/.ssh"

if [[ "${HAS_CHECKED_OUT}" != "true" ]]; then
    echo "WARNING: repo not checked out; attempting checkout" > /dev/stderr
    echo "WARNING: this may result in missing commits in the remote mirror" > /dev/stderr
    echo "WARNING: this behavior is deprecated and will be removed in a future release" > /dev/stderr
    echo "WARNING: to remove this warning add the following to your yml job steps:" > /dev/stderr
    echo " - uses: actions/checkout@v3" > /dev/stderr
    if [[ "${SRC_REPO}" -eq "" ]]; then
        echo "WARNING: SRC_REPO env variable not defined" > /dev/stderr
        SRC_REPO="https://github.com/${GITHUB_REPOSITORY}.git" > /dev/stderr
        echo "Assuming source repo is ${SRC_REPO}" > /dev/stderr
     fi
    git init > /dev/null
    git remote add origin "${SRC_REPO}"
    git fetch --all > /dev/null 2>&1
fi

git config --global credential.username "${GIT_USERNAME}"


if [[ "${GIT_SSH_PRIVATE_KEY}" != "" ]]; then
    mkdir -p ${SSH_DIR}
    chmod 700 ${SSH_DIR}
    echo "${GIT_SSH_PRIVATE_KEY}" > ${SSH_DIR}/id_rsa
    if [[ "${GIT_SSH_PUBLIC_KEY}" != "" ]]; then
        echo "${GIT_SSH_PUBLIC_KEY}" > ${SSH_DIR}/id_rsa.pub
        chmod 600 ${SSH_DIR}/id_rsa.pub
    fi
    chmod 600 ${SSH_DIR}/id_rsa
    if [[ "${GIT_SSH_KNOWN_HOSTS}" != "" ]]; then
      echo "${GIT_SSH_KNOWN_HOSTS}" > ${SSH_DIR}/known_hosts
      git config --global core.sshCommand "ssh -i ${SSH_DIR}/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=${SSH_DIR}/known_hosts"
    else
      if [[ "${GIT_SSH_NO_VERIFY_HOST}" != "true" ]]; then
        echo "WARNING: no known_hosts set and host verification is enabled (the default)"
        echo "WARNING: this job will fail due to host verification issues"
        echo "Please either provide the GIT_SSH_KNOWN_HOSTS or GIT_SSH_NO_VERIFY_HOST inputs"
        exit 1
      else
        git config --global core.sshCommand "ssh -i ${SSH_DIR}/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
      fi
    fi
else
    git config --global core.askPass /cred-helper.sh
    git config --global credential.helper cache
fi

git remote add ${REMOTE_NAME} "${REMOTE}"
if [[ "${INPUT_PUSH_ALL_REFS}" != "false" ]]; then
    eval git push ${GIT_PUSH_ARGS} ${REMOTE_NAME} "\"refs/remotes/origin/*:refs/heads/*\""
else
    if [[ "${HAS_CHECKED_OUT}" != "true" ]]; then
        echo "FATAL: You must upgrade to using actions inputs instead of args: to push a single branch" > /dev/stderr
        exit 1
    else
        eval git push -u ${GIT_PUSH_ARGS} ${REMOTE_NAME} "${GITHUB_REF}"
    fi
fi
