#!/bin/bash

set -e
set -u
set -x
set -v


#Only attempt to deploy if we know the ssh key secrets, username and server
if test -z ${encrypted_49475b8073e9_key:+decryp_key} ; then exit 0; fi
if test -z ${encrypted_49475b8073e9_iv:+decrypt_iv} ; then exit 0; fi
if test -z ${DEPLOY_USER:+username} ; then exit 0; fi
if test -z ${DEPLOY_SERVER:+server} ; then exit 0; fi

# Prepare the ssh homedir.
#
# Decrypting the ssh private key for deploying to the server.
# See https://docs.travis-ci.com/user/encrypting-files/ for details.
mkdir -p -m 0700 ~/.ssh
openssl aes-256-cbc \
  -K $encrypted_49475b8073e9_key \
  -iv $encrypted_49475b8073e9_iv \
  -in $TRAVIS_BUILD_DIR/.credentials/delta.id_rsa.enc \
  -out ~/.ssh/id_rsa -d
chmod 600 ~/.ssh/id_rsa
printf "Host *\n" >> ~/.ssh/config
printf " %sAuthentication no\n" ChallengeResponse Password KbdInteractive >> ~/.ssh/config


# Perform the actual deploy to py.delta.chat
rsync -avz \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  $TRAVIS_BUILD_DIR/python/doc/_build/html/ \
  ${DEPLOY_USER}@${DEPLOY_SERVER}:build/${TRAVIS_BRANCH/\//_}

# Perform the actual deploy to c.delta.chat
rsync -avz \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  $TRAVIS_BUILD_DIR/docs/html/ \
  ${DEPLOY_USER}@${DEPLOY_SERVER}:build-c/${TRAVIS_BRANCH/\//_}
