#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /tools/go-rpm-macros/Sanity/gobuild-grafana
#   Description: golang rpm macros usage building grafana
#   Author: Jan Kuřík <jkurik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="go-rpm-macros"

GO_PACKAGE="$(rpm -qf $(which go))"

# Conserve the non-zero return value through the pipe
set -o pipefail

rlJournalStart
    rlPhaseStartSetup
        rlRun "TmpDir=\$(mktemp -d /var/tmp/XXXXXXX)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest "check macros"
        rlRun "gobuild_string=\"$(rpm -E '%gobuild')\"" 127
        rlRun "gotest_string=\"$(rpm -E '%gotest')\"" 127
        rlAssertNotEquals "Checking if %gobuild macro is defined" "$gobuild_string" "%gobuild"
        rlAssertNotEquals "Checking if %gotest macro is defined" "$gotest_string" "%gotest"
    rlPhaseEnd

    rlPhaseStart FAIL "setup grafana sources"
        rlRun "SRPM=\$(basename \$(yumdownloader --source --url grafana | tail -n 1))"
        rlRun "yumdownloader --source grafana"
        rlRun "yum-builddep --enablerepo=\* -y --srpm ${SRPM}"
        rlRun "rpm -i -D '_topdir $TmpDir' ${SRPM}"
        rlRun "sed -i 's/^\s*%define\s*compile_frontend\s.*/%define compile_frontend 0/g' \
            SPECS/grafana.spec" 0 "Make sure we build only the golang part, no JS stuff"
    rlPhaseEnd

    rlPhaseStartTest "rpmbuild grafana"
        rlRun "rpmbuild --showrc &> ${TmpDir}/rpm.rc"
        rlFileSubmit "${TmpDir}/rpm.rc"
        rlAssertGrep "%gobuild" SPECS/grafana.spec -w
        rlAssertGrep "%gotest" SPECS/grafana.spec -w
        rlRun "rpmbuild -bc --define='_topdir $TmpDir' SPECS/grafana.spec \
            |& tee grafana.rpmbuild.log"
        rlFileSubmit "grafana.rpmbuild.log"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
