# neo4j

## top/bottom N categories

```sql
MATCH (category:category)<-[:belong_to]-()
WITH category, count(*) AS categoryCount
RETURN category.title AS categoryTitle, categoryCount
ORDER BY categoryCount DESC // or ASC for bottom
LIMIT 3 // carefull, will hang your host
```

## shortest path between two nodes

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
MATCH path = SHORTESTPATH((source)-[:link_to|redirect_to*1..100]->(target))
RETURN path
```

## all shortest paths between two nodes

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1..100]->(target))
// WITH path SKIP 0 LIMIT 10
RETURN paths
```

## all shortest paths between two nodes + consider redirects as target

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
OPTIONAL MATCH (r:redirect)-[:redirect_to]->(target)
WITH source, target, [target] + COLLECT(r) AS endNodes
WITH source, [n IN endNodes WHERE elementId(n) <> elementId(source)] AS filteredEndNodes
UNWIND filteredEndNodes AS endNode
MATCH p = ALLSHORTESTPATHS ((source)-[:link_to|redirect_to*1..20]->(endNode))
WITH p, length(p) AS plen
WITH collect(p) AS collectedNormalPaths, min(plen) AS minLength
UNWIND [q IN collectedNormalPaths WHERE length(q) = minLength] AS shortestNormalPaths
WITH shortestNormalPaths, last(nodes(shortestNormalPaths)) AS pathEnd
OPTIONAL MATCH redirectHop = (pathEnd)-[:redirect_to]->(target)
WITH
  CASE
    WHEN redirectHop IS NULL THEN shortestNormalPaths
    ELSE apoc.path.combine(shortestNormalPaths, redirectHop)
  END AS finalPath
RETURN finalPath;
```

## all shortest paths between two nodes + categories of each node

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1..100]->(target))
// WITH paths SKIP 0 LIMIT 10
UNWIND nodes(paths) AS nodes
OPTIONAL MATCH belongs = (nodes)-[:belong_to]->(categories:category)
RETURN paths, nodes, belongs, categories
```

## all categories of all shortest paths between two nodes

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1..100]->(target))
// WITH paths SKIP 0 LIMIT 10
UNWIND nodes(paths) AS nodes
OPTIONAL MATCH belongs = (nodes)-[:belong_to]->(categories:category)
RETURN COLLECT(DISTINCT categories)
```

## orphan pages (long running procedure)

```sql
CALL
  apoc.periodic.iterate(
    "MATCH (node:page) WHERE NOT EXISTS((node)-[:link_to]->()) AND NOT EXISTS((node)<-[:link_to|redirect_to]-()) RETURN node",
    "CREATE (orphan:orphan {id: node.pageId, title: node.title, type:labels(node)[0], createdAt: timestamp()}) WITH orphan, node
   CALL apoc.log.info('orphan\tid:%s\ttitle:%s\ttype:%s', [orphan.id, orphan.title, orphan.type])
   RETURN orphan",
    {batchSize: 10000, parallel: true}
  )
  YIELD batches, total
RETURN batches, total

// wait for procedure to finish
```

```sql
MATCH (orphan:orphan) RETURN orphan
```

## batch delete

```sql
CALL
  apoc.periodic.iterate(
    "MATCH (node:orphan) RETURN node",
    "DETACH DELETE node",
    {batchSize: 10000, parallel: true}
  )
  YIELD batches, total
RETURN batches, total
```

## all nodes belonging to a category

```sql
MATCH (target:category {title: "The_Lord_of_the_Rings_characters"})
MATCH (node)-[:belong_to]->(target)
RETURN node
ORDER BY node.title
SKIP 0
LIMIT 10 // carefull, will hang your host
```
