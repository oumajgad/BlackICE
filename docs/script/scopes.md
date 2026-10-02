# Script scopes

<!-- The keyword lists come from CTrigger::LoadKey and CEffect::LoadKey, read out of
     the game itself. reversing/findings/FINDINGS-script.md in the reversing folder has the save token
     and implementing class of every one. -->

A scope decides *who* a block of triggers or effects is about. Without one, a
trigger tests the country the event is firing for and an effect applies to it; a scope
points both at somebody else - a neighbour, a province owner, every country in a faction.

Scopes nest, and `limit` narrows one. See
[the overview](README.md#scopes-change-who-the-block-is-about).

## Scopes

| Keyword | What it does | Syntax | Uses in the mod |
| --- | --- | --- | --- |
| `and` | All parts of the group are valid. | `and = { ... }` | 7448 |
| `or` | At least one part of the group is valid. | `or = { ... }` | 2410 |
| `not` | No parts of the group are valid. # While this should have an implicit AND inside of it, it does not always work correctly unless you explicitly state the AND | `not = { ... }` | 17880 |
| `country tag` | The specified country. | `tag  = { effects… }` |  |
| `FROM` | The country that triggered the current event. | `FROM  = { effects… }` | 512 |
| `THIS` | The current country. | `THIS  = { effects… }` | 784 |
| `limit` | Limits the given scope to more narrow conditions. (for example - an event 500 will fire for any/every country in Axis:) | `limit = { ... }` | 5898 |
| `any_neighbor_country` | Any country neighboring the current country. | `any_neighbor_country = { triggers… }` | 1 |
| `any_neighbor_province` | Any province neighboring the current province. | `any_neighbor_province = { triggers… }` | 116 |
| `any_owned_province` | Any owned province. | `any_owned_province = { triggers… }` | 72 |
| `any_core` | Any province that is a core of the current country. | `any_core = { triggers… }` |  |
| `any_country` | Any available country. | `any_country = { effects… }` | 4236 |
| `random_country` | Picks a random country. | `random_country = { effects… }` | 87 |
| `any_owned` | Any owned province. | `any_owned = { effects… }` | 130 |
| `any_controlled` | Any controlled province. | `any_controlled = { effects… }` | 277 |
| `random_owned` | Picks a random province. | `random_owned = { effects… }` | 806 |
| `owner` | The current owner of the province. | `owner  = { effects… }` | 37 |
| `controller` | The country currently controlling the province. | `controller  = { effects… }` | 1536 |
| `capital_scope` | Capital of the current country. | `capital_scope = { effects… }` | 39 |
| `province id` | The specified province. | `<province id>  = { effects… }` |  |
| `region name` | The specified region. | `<region name>  = { effects… }` |  |
| `random_neighbor_province` | Picks a random province neighboring the current province. | `random_neighbor_province = { effects… }` | 8 |
| `random_empty_neighbor_province` | Picks a random empty province neighboring the current province. | `random_empty_neighbor_province = { effects… }` |  |
