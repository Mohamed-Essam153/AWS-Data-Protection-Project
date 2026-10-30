# Architecture diagrams

| Diagram | Source |
|---|---|
| [Main architecture](main-architecture.png) | [main-architecture.dot](main-architecture.dot) |
| [Data lifecycle](data-lifecycle.png) | [data-lifecycle.dot](data-lifecycle.dot) |
| [Data in transit](data-in-transit.png) | [data-in-transit.dot](data-in-transit.dot) |

They're Graphviz files so they can be reviewed in a pull request like any other change. To regenerate after editing:

```bash
dot -Tpng -Gdpi=150 main-architecture.dot -o main-architecture.png
```
