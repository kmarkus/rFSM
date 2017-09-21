![rFSM logo](/doc/rFSM_logo.jpg)

rFSM Statecharts (v1.0)
=======================

What is it?
-----------

rFSM is a small and powerful Statechart implementation. It is mainly
used for *Coordination* of complex systems but is not limited to
that. rFSM is written in pure Lua and is therefore highly portable and
embeddable. As a Lua domain specific language rFSM inherits the
extensibility of its host language.

Documentation
-------------

See the [rFSM documentation](doc/rFSM-manual.md)

Information about how to use rFSM using the OROCOS RTT Framework can
be found
[here](http://www.orocos.org/wiki/orocos/toolchain/LuaCookbook).


Download
--------

The code can be found in [this](https://github.com/kmarkus/rFSM) git
repository.

A cheatsheet summarizing the DSL is available
[here](https://github.com/kmarkus/rfsm-cheatsheet/raw/master/cheatsheet.pdf).

License
-------

rFSM is dual licensed under LGPL/BSD.

Contact
-------

Please direct questions, bugs or improvements to the
[orocos-users](http://lists.mech.kuleuven.be/mailman/listinfo/orocos-users)
mailing list.


Acknowledgement
---------------

- Funding

  The research leading to these results has received funding from
  the European Community's Seventh Framework Programme
  (FP7/2007-2013) under grant agreement no. FP7-ICT-231940-BRICS
  (Best Practice in Robotics)

- Scientific background

  This work borrows many ideas from the Statecharts by David Harel
  and some from UML 2.1 State Machines. The following publications
  are the most relevant

  David Harel and Amnon Naamad. 1996. The STATEMATE semantics of
  statecharts. ACM Trans. Softw. Eng. Methodol. 5, 4 (October 1996),
  293-333. DOI=10.1145/235321.235322
  <http://doi.acm.org/10.1145/235321.235322>

  The OMG UML Specification:
  <http://www.omg.org/spec/UML/2.3/Superstructure/PDF/>
