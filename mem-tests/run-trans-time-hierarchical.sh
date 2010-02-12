#!/bin/bash

#
# Test the garbage collection duration for the 
#
LUA=/home/mk/bin/tlsf-lua
SCRIPT=transition-time-hierarchical-fsm.lua
NUM_STEPS=10000

for DEPTH in  1 3 5 10; do
    for NUM_STATES in 10 20 30 40 50 60 70 80 90 100; do
	# echo "$NUM_STEPS $NUM_STATES $DEPTH"
	sudo env LUA_PATH=$LUA_PATH LUA_CPATH=$LUA_CPATH $LUA $SCRIPT $NUM_STEPS $NUM_STATES $DEPTH >> transition-time-$NUM_STEPS-$DEPTH.data
    done
done



