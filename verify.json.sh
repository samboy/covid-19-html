#!/bin/bash

# This is a shell script which verifies the JSON on the standard input
python -c 'import sys,json;print json.dumps(json.loads(sys.stdin.read()),
	sort_keys=True, indent=4);'
