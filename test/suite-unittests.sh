#!/bin/bash
#
# Run the epan unit tests
#
# $Id$
#
# Wireshark - Network traffic analyzer
# By Gerald Combs <gerald@wireshark.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

if [ "$WS_SYSTEM" == "Windows" ] ; then
	MAKE="nmake -f Makefile.nmake"
else
	MAKE=make
fi

unittests_step_test() {
	( cd `dirname $DUT` && $MAKE `basename $DUT` ) >testout.txt 2>&1
	if [ $? -ne 0 ]; then
		echo
		cat ./testout.txt
		test_step_failed "make $DUT failed"
		return
	fi

	# if we're on windows, we have to copy the test exe to the wireshark-gtk2
	# dir before we can use them.
	# {Note that 'INSTALL_DIR' must be a Windows Pathname)
	if [ "$WS_SYSTEM" == "Windows" ] ; then
		(cd `dirname $DUT` && $MAKE `basename $DUT`_install INSTALL_DIR='wireshark-gtk2\') > testout.txt 2>&1
		if [ $? -ne 0 ]; then
			echo
			cat ./testout.txt
			test_step_failed "install $DUT failed"
			return
		fi
		DUT=$SOURCE_DIR/wireshark-gtk2/`basename $DUT`
	fi

	$DUT $ARGS > testout.txt 2>&1
	RETURNVALUE=$?
	if [ ! $RETURNVALUE -eq $EXIT_OK ]; then
		echo
		cat ./testout.txt
		test_step_failed "exit status of $DUT: $RETURNVALUE"
		return
	fi
	test_step_ok
}


unittests_step_exntest() {
	DUT=$SOURCE_DIR/epan/exntest
	ARGS=
	unittests_step_test
}

unittests_step_lua_dissector_test() {
	if [ $HAVE_LUA -ne 0 ]; then
		test_step_skipped
		return
	fi

	# First run tshark with the dissector script.
	$TSHARK -r $CAPTURE_DIR/dns_port.pcap -V -X lua_script:$TESTS_DIR/lua/dissector.lua > testin.txt 2>&1
	RETURNVALUE=$?
	if [ ! $RETURNVALUE -eq $EXIT_OK ]; then
		echo
		cat ./testin_tmp.txt
		test_step_failed "exit status of $DUT: $RETURNVALUE"
		return
	fi

	# then run tshark again with the verification script. (it internally reads in testin.txt)
	$TSHARK -r $CAPTURE_DIR/dns_port.pcap -X lua_script:$TESTS_DIR/lua/verify_dissector.lua > testout.txt 2>&1
	if grep -q "All tests passed!" testout.txt; then
		test_step_ok
	else
		echo
		cat ./testin.txt
		cat ./testout.txt
		test_step_failed "didn't find pass marker"
	fi
}

unittests_step_lua_int64_test() {
	if [ $HAVE_LUA -ne 0 ]; then
		test_step_skipped
		return
	fi

	# Tshark catches lua script failures, so we have to parse the output.
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/int64.lua > testout.txt 2>&1
	if grep -q "All tests passed!" testout.txt; then
		test_step_ok
	else
		echo
		cat ./testout.txt
		test_step_failed "didn't find pass marker"
	fi
}

unittests_step_lua_args_test() {
	if [ $HAVE_LUA -ne 0 ]; then
		test_step_skipped
		return
	fi

	# Tshark catches lua script failures, so we have to parse the output.
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/script_args.lua -X lua_script1:1 > testout.txt 2>&1
	grep -q "All tests passed!" testout.txt
	if [ $? -ne 0 ]; then
		cat testout.txt
		test_step_failed "lua_args_test test 1 failed"
	fi
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/script_args.lua -X lua_script1:3 -X lua_script1:foo -X lua_script1:bar > testout.txt 2>&1
	grep -q "All tests passed!" testout.txt
	if [ $? -ne 0 ]; then
		cat testout.txt
		test_step_failed "lua_args_test test 2 failed"
	fi
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/script_args.lua -X lua_script:$TESTS_DIR/lua/script_args.lua -X lua_script1:3 -X lua_script2:1 -X lua_script1:foo -X lua_script1:bar > testout.txt 2>&1
	grep -q "All tests passed!" testout.txt
	if [ $? -ne 0 ]; then
		cat testout.txt
		test_step_failed "lua_args_test test 3 failed"
	fi
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/script_args.lua > testout.txt 2>&1
	if grep -q "All tests passed!" testout.txt; then
		cat testout.txt
		test_step_failed "lua_args_test negative test 4 failed"
	fi
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/script_args.lua -X lua_script1:3 > testout.txt 2>&1
	if grep -q "All tests passed!" testout.txt; then
		cat testout.txt
		test_step_failed "lua_args_test negative test 5 failed"
	fi
	test_step_ok
}

unittests_step_lua_struct_test() {
	if [ $HAVE_LUA -ne 0 ]; then
		test_step_skipped
		return
	fi

	# Tshark catches lua script failures, so we have to parse the output.
	$TSHARK -r $CAPTURE_DIR/dhcp.pcap -X lua_script:$TESTS_DIR/lua/struct.lua > testout.txt 2>&1
	if grep -q "All tests passed!" testout.txt; then
		test_step_ok
	else
		cat testout.txt
		test_step_failed "didn't find pass marker"
	fi
}

unittests_step_oids_test() {
	DUT=$SOURCE_DIR/epan/oids_test
	ARGS=
	unittests_step_test
}

unittests_step_reassemble_test() {
	DUT=$SOURCE_DIR/epan/reassemble_test
	ARGS=
	unittests_step_test
}

unittests_step_tvbtest() {
	DUT=$SOURCE_DIR/epan/tvbtest
	ARGS=
	unittests_step_test
}

unittests_step_wmem_test() {
	DUT=$SOURCE_DIR/epan/wmem/wmem_test
	ARGS=--verbose
	unittests_step_test
}

unittests_cleanup_step() {
	rm -f ./testout.txt
	rm -f ./testin.txt
}

unittests_suite() {
	test_step_set_pre unittests_cleanup_step
	test_step_set_post unittests_cleanup_step
	test_step_add "exntest" unittests_step_exntest
	test_step_add "lua dissector" unittests_step_lua_dissector_test
	test_step_add "lua int64" unittests_step_lua_int64_test
	test_step_add "lua script arguments" unittests_step_lua_args_test
	test_step_add "lua struct" unittests_step_lua_struct_test
	test_step_add "oids_test" unittests_step_oids_test
	test_step_add "reassemble_test" unittests_step_reassemble_test
	test_step_add "tvbtest" unittests_step_tvbtest
	test_step_add "wmem_test" unittests_step_wmem_test
}
#
# Editor modelines  -  http://www.wireshark.org/tools/modelines.html
#
# Local variables:
# c-basic-offset: 8
# tab-width: 8
# indent-tabs-mode: t
# End:
#
# vi: set shiftwidth=8 tabstop=8 noexpandtab:
# :indentSize=8:tabSize=8:noTabs=false:
#
