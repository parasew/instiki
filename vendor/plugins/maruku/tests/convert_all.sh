#!/bin/bash

ruby -I../lib ../bin/maruku MarkdownTest_1.0/Tests/*.text

ruby -I../lib ../bin/maruku others/*.md
#ruby -I../lib ../bin/marutex others/*.md
