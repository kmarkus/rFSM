cmake_minimum_required(VERSION 2.8.3)
project(rfsm)

find_package(catkin REQUIRED)
catkin_package()
catkin_add_env_hooks(10.rfsm SHELLS sh DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/env-hooks)

#############
## Install ##
#############

# all install targets should use catkin DESTINATION variables
# See http://ros.org/doc/api/catkin/html/adv_user_guide/variables.html

file(GLOB LUA_FILES "*.lua")
install(
  FILES ${LUA_FILES}
  DESTINATION ${CATKIN_GLOBAL_SHARE_DESTINATION}/lua/5.1/rfsm/
)

install(
  PROGRAMS tools/rfsm-sim tools/rfsm-viz tools/rfsm2json
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(
  FILES tools/rfsm-sim.lua
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

