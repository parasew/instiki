
# 
ruby -I../../lib use_itex.rb < private.txt

# creates the pdf

ruby -I../../lib ../../bin/maruku --pdf private.txt
