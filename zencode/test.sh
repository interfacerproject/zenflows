#!/usr/bin/env bash

conf="rngseed=hex:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

which zenroom > /dev/null
if [ $? != 0 ]; then
	echo "Error: zenroom interpreter not found in PATH"
	exit 1
fi
if ! ls ./*.zen >/dev/null 2>&1 ; then
	echo "Error: there is no zencode scripts in PWD to run"
	exit 1
fi

results=`mktemp`
echo > $results
echo "Zenflows tests of zencode scripts" >> $results
date >> $results
echo >> $results

function testzen() {
    script="${1}.zen"
    expect="$2"
    input="$3"
    if [ "$input" != "" ]; then
	tmpin=`mktemp`
	echo "$input" > $tmpin
	result=`cat $script | zenroom -z -c $conf -a $tmpin`
	rm -f $tmpin
    else
	result=`cat $script | zenroom -z -c $conf`
    fi
    if [ $? != 0 ]; then
	echo "[!] Parse error in $script" >> $results
    else
	if [ "$result" != "$expect" ]; then
	    echo "[!] Error in $script" >> $results
	    echo "$result"
	else
	    echo " .  Success: $script" >> $results
	fi
    fi
}

testzen keygen '{"bitcoin_address":"bc1qlsqa5rgnrma4agtjar4q5jv9pe4pxze7vsyvp7","ethereum_address":"05a94ba6d94f9056e79351a8fd1dc186b737993f","keyring":{"bitcoin":"L1ipn47zzKEDFhbHgJ3ef4Hwpf3ACu4CHEzDGXdJ4Wh6DtjV1woo","ecdh":"B4rYTWx6UMbc2YPWRNpl4w2M6gY9jqSa637n8Kr2pPc=","ethereum":"d6fe79ff70b4a8663d1ecf495a983ba6effd0392c636923dff08a0482f5e5d5f","reflow":"abYTJShT0ZBKU+ZwJlEIPNinT6TFU+unaKMEZ+u3kbs=","schnorr":"DR92VSF2l3Az1K1+LyWO13Jk1eBPmuhhPT2NbpxGgsk="},"pubkeys":{"ecdh_public_key":"BHdrWMNBRclVO1I1/iEaYjfEi5C0eEvG2GZgsCNq87qy8feZ74JEvnKK9FC07ThhJ8s4ON2ZQcLJ+8HpWMfKPww=","reflow_public_key":"FwWLOfRBAoZKfykEvq26iNn2D64gvwgCfinWWZnG4HotCuomB6EB9qJ0sinpV5LNB6GdkrKU3wvYMUU+fBMX8mtR77E3x/ljbqpwwpcmjB9YtONG1peywJvRhXqhIBJSALFTXAB2Y1XtM63Uw5/CBex8zH3wXyYU6sv/ctKi5bUZ2Zzqua9Q8LMqtgLsrrB9GDKbmPT1einkXVMLX0kuJV/AOTnA57q91HKXMCvlvlKs/sr5mJ70FchdEZl0UHIV","schnorr_public_key":"EZH/DtDoGvjabyqiHwROQpt5suHlD3JiMZ7Cqv8yAWZpewOm8i5TlOq6L6eBbc/J"}}'

testzen passgen_pbkdf2 '{"key_derivation":"hUWpLrhAYoeWA/0uNjn32a/YNwQc8S1mAI0IpWgPMLU="}' '{"salt":"c24463f5e352da20cb79a43f97436cce57344911e1d0ec0008cbedb5fabcca33","password":"my secret pass"}'

testzen passverify_pbkdf2 '{"output":["1"]}' '{"hash":"hUWpLrhAYoeWA/0uNjn32a/YNwQc8S1mAI0IpWgPMLU=","salt":"c24463f5e352da20cb79a43f97436cce57344911e1d0ec0008cbedb5fabcca33","password": "my secret pass"}'

echo >> $results
cat $results
rm -f $results


