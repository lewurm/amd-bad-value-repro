#!/bin/bash

MONO_PATH="`pwd`" ./mono-sgen --compile 'System.Uri:PrivateParseMinimal' mscorlib -O=-aot --debug
