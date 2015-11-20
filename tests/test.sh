#!/bin/bash

set -e

DOCKER2ACI=../bin/docker2aci
PREFIX=docker2aci-tests
TESTDIR=$(dirname $(realpath $0))

cd $TESTDIR

# install rkt in Semaphore
if ! which rkt > /dev/null ; then
	if [ "$SEMAPHORE" != "true" ] ; then
		echo "Please install rkt"
		exit 1
	fi
	pushd $SEMAPHORE_CACHE_DIR
	if ! md5sum -c $TESTDIR/rkt-v0.11.0.md5sum; then
		wget https://github.com/coreos/rkt/releases/download/v0.11.0/rkt-v0.11.0.tar.gz
	fi
	md5sum -c $TESTDIR/rkt-v0.11.0.md5sum
	tar xf rkt-v0.11.0.tar.gz
	export PATH=$PATH:$PWD/rkt-v0.11.0/
	popd
fi
RKT=$(which rkt)

for i in $(find . -maxdepth 1 -type d -name 'test-*') ; do
	TESTNAME=$(basename $i)
	echo "### Test case ${TESTNAME}: build..."
	sudo docker build --tag=$PREFIX/${TESTNAME} --no-cache=true ${TESTNAME}

	echo "### Test case ${TESTNAME}: test in Docker..."
	sudo docker run --rm $PREFIX/${TESTNAME}

	echo "### Test case ${TESTNAME}: converting to ACI..."
	sudo docker save -o ${TESTNAME}.docker $PREFIX/${TESTNAME}
	$DOCKER2ACI ${TESTNAME}.docker

	echo "### Test case ${TESTNAME}: test in rkt..."
	sudo $RKT run --insecure-skip-verify ./${PREFIX}-${TESTNAME}-latest.aci

	echo "### Test case ${TESTNAME}: test with 'rkt image render'..."
	sudo $RKT image render --overwrite ${PREFIX}/${TESTNAME} ./rendered-${TESTNAME}
	if [ -x $TESTDIR/${TESTNAME}/check.sh ] ; then
		pushd rendered-${TESTNAME}/rootfs
		rendered=true $TESTDIR/${TESTNAME}/check.sh
		popd
	fi
	echo "### Test case ${TESTNAME}: SUCCESS"

	sudo docker rmi $PREFIX/${TESTNAME}
done

