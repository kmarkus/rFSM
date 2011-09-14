LUA=lua
TEST=`echo fsmtest_*`
#TEST="test_simple.lua"

rm -f *.png

for t in $TEST; do
    echo -e "\n\n*********************************** $t ********************************************"
    $LUA $t
done
