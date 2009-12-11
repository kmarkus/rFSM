
TEST=`echo fsmtest_*`
#TEST="test_simple.lua"

rm -f *.png

for t in $TEST; do
    lua $t
done
