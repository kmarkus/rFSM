local rfsm = require("rfsm")
return rfsm.state {

    outer_a = rfsm.state{

        middle_a = rfsm.state{
            inner_a = rfsm.state{
                node_a = rfsm.state{},
                node_b = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_a"},
                rfsm.trans{src="node_a", tgt="node_b", events={'tick'}},
                rfsm.trans{src="node_b", tgt="node_a", events={'tick'}},
            },
            inner_b = rfsm.state{
                node_c = rfsm.state{},
                node_d = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_c"},
                rfsm.trans{src="node_c", tgt="node_d", events={'tick'}},
                rfsm.trans{src="node_d", tgt="node_c", events={'tick'}},
            },
            
            rfsm.trans{src="initial", tgt="inner_a"},
            rfsm.trans{src="inner_a", tgt="inner_b", events={'tick'}},
            rfsm.trans{src="inner_b", tgt="inner_a", events={'tick'}},
        },
        middle_b = rfsm.state{
            inner_c = rfsm.state{
                node_e = rfsm.state{},
                node_f = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_e"},
                rfsm.trans{src="node_e", tgt="node_f", events={'tick'}},
                rfsm.trans{src="node_f", tgt="node_e", events={'tick'}},
            },
            inner_d = rfsm.state{
                node_g = rfsm.state{},
                node_h = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_g"},
                rfsm.trans{src="node_g", tgt="node_h", events={'tick'}},
                rfsm.trans{src="node_h", tgt="node_g", events={'tick'}},
            },

            rfsm.trans{src="initial", tgt="inner_c"},
            rfsm.trans{src="inner_c", tgt="inner_d", events={'tick'}},
            rfsm.trans{src="inner_d", tgt="inner_c", events={'tick'}},
        },

        rfsm.trans{src="initial", tgt="middle_a"},
        rfsm.trans{src="middle_a", tgt="middle_b", events={'tick'}},
        rfsm.trans{src="middle_b", tgt="middle_a", events={'tick'}},

    },
    outer_b = rfsm.state{

        middle_c = rfsm.state{

            inner_e = rfsm.state{
                node_i = rfsm.state{},
                node_j = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_i"},
                rfsm.trans{src="node_i", tgt="node_j", events={'tick'}},
                rfsm.trans{src="node_j", tgt="node_i", events={'tick'}},
            },
            inner_f = rfsm.state{
                node_k = rfsm.state{},
                node_l = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_k"},
                rfsm.trans{src="node_k", tgt="node_l", events={'tick'}},
                rfsm.trans{src="node_l", tgt="node_k", events={'tick'}},
            },
            
            rfsm.trans{src="initial", tgt="inner_e"},
            rfsm.trans{src="inner_e", tgt="inner_f", events={'tick'}},
            rfsm.trans{src="inner_f", tgt="inner_e", events={'tick'}},

        },
        middle_d = rfsm.state{

            inner_g = rfsm.state{
                node_m = rfsm.state{},
                node_n = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_m"},
                rfsm.trans{src="node_m", tgt="node_n", events={'tick'}},
                rfsm.trans{src="node_n", tgt="node_m", events={'tick'}},
            },
            inner_h = rfsm.state{
                node_o = rfsm.state{},
                node_p = rfsm.state{},
                rfsm.trans{src="initial", tgt="node_o"},
                rfsm.trans{src="node_o", tgt="node_p", events={'tick'}},
                rfsm.trans{src="node_p", tgt="node_o", events={'tick'}},
            },
            rfsm.trans{src="initial", tgt="inner_g"},
            rfsm.trans{src="inner_g", tgt="inner_h", events={'tick'}},
            rfsm.trans{src="inner_h", tgt="inner_g", events={'tick'}},
        },

        rfsm.trans{src="initial", tgt="middle_c"},
        rfsm.trans{src="middle_c", tgt="middle_d", events={'tick'}},
        rfsm.trans{src="middle_d", tgt="middle_c", events={'tick'}},

    },

    rfsm.trans{src="initial", tgt="outer_a"},
    rfsm.trans{src="outer_a", tgt="outer_b", events={'tick'}},
    rfsm.trans{src="outer_b", tgt="outer_a", events={'tick'}},

}
