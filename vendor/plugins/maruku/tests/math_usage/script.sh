
maruku="ruby -I../../lib ../../bin/maruku"

#input="private.txt"
input="document.md"

$maruku -m itex2mml -o itex2mml.xhtml $input
$maruku -m ritex    -o ritex.xhtml  $input
$maruku -m none     -o none.html  $input
$maruku -m blahtex  -o blahtex.xhtml  $input
$maruku -m none    --math-images blahtex  -o blahtexi.html  $input
$maruku -m blahtex --math-images blahtex  -o blahtexmi.xhtml  $input
 
