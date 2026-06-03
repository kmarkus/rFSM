# Example state machine diagrams

These diagrams are rendered from the models in [`../../../examples/`](../../../examples)
with the [`rfsm.plantuml`](../../../README.md#rfsmplantuml-plantuml-state-diagram-export)
exporter. Regenerate them with:

```sh
tools/rfsm2plantuml examples/<model>.lua   # writes a .puml next to the model
plantuml -tpng <model>.puml                # render to png
```

## Basics

| Model | Diagram |
|-------|---------|
| [`hello_world.lua`](../../../examples/hello_world.lua) | ![hello_world](hello_world.png) |
| [`simple.lua`](../../../examples/simple.lua) | ![simple](simple.png) |
| [`introductory.lua`](../../../examples/introductory.lua) | ![introductory](introductory.png) |
| [`simple_doo_idle.lua`](../../../examples/simple_doo_idle.lua) | ![simple_doo_idle](simple_doo_idle.png) |
| [`simple_idle_doo.lua`](../../../examples/simple_idle_doo.lua) | ![simple_idle_doo](simple_idle_doo.png) |

## Connectors

| Model | Diagram |
|-------|---------|
| [`connector_simple.lua`](../../../examples/connector_simple.lua) | ![connector_simple](connector_simple.png) |
| [`connector_split.lua`](../../../examples/connector_split.lua) | ![connector_split](connector_split.png) |
| [`connector_cycles.lua`](../../../examples/connector_cycles.lua) | ![connector_cycles](connector_cycles.png) |
| [`connector_cycles2.lua`](../../../examples/connector_cycles2.lua) | ![connector_cycles2](connector_cycles2.png) |

## Composite & nested states

| Model | Diagram |
|-------|---------|
| [`composite_nested.lua`](../../../examples/composite_nested.lua) | ![composite_nested](composite_nested.png) |
| [`composite_exitconn.lua`](../../../examples/composite_exitconn.lua) | ![composite_exitconn](composite_exitconn.png) |
| [`relative_trans.lua`](../../../examples/relative_trans.lua) | ![relative_trans](relative_trans.png) |
| [`subgraphs.lua`](../../../examples/subgraphs.lua) | ![subgraphs](subgraphs.png) |

## Extensions & misc

| Model | Diagram |
|-------|---------|
| [`emem_test.lua`](../../../examples/emem_test.lua) | ![emem_test](emem_test.png) |
| [`monitor_state.lua`](../../../examples/monitor_state.lua) | ![monitor_state](monitor_state.png) |
| [`timeevent.lua`](../../../examples/timeevent.lua) | ![timeevent](timeevent.png) |
| [`preview_example.lua`](../../../examples/preview_example.lua) | ![preview_example](preview_example.png) |
| [`preview_example2.lua`](../../../examples/preview_example2.lua) | ![preview_example2](preview_example2.png) |
| [`total_failure.lua`](../../../examples/total_failure.lua) | ![total_failure](total_failure.png) |
| [`ball_tracker.lua`](../../../examples/ball_tracker.lua) | ![ball_tracker](ball_tracker.png) |
| [`ball_tracker_scope.lua`](../../../examples/ball_tracker_scope.lua) | ![ball_tracker_scope](ball_tracker_scope.png) |
