# neo4j

## top/bottom N categories

```sql
MATCH (category:category)<-[:belong_to]-()
WITH category, count(*) AS categoryCount
RETURN category.title AS categoryTitle, categoryCount
ORDER BY categoryCount DESC // or ASC for bottom
SKIP 0 LIMIT 3 // carefull, will hang your host
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
WITH paths, [node IN nodes(paths) | node.title] AS titles
ORDER BY titles
// SKIP 0 LIMIT 10
return paths
```

optimized

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
CALL (source, target) {
  MATCH path = SHORTESTPATH((source)-[:link_to|redirect_to*1..100]->(target))
  RETURN length(path) AS len
}
CALL
  apoc.cypher.run(
    "MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1.." + len + "]->(target))
    WITH paths, [node IN nodes(paths) | node.title] AS titles
    ORDER BY titles
    // SKIP 0 LIMIT 10
    return paths",
    {source: source, target: target, len:len}
  )
YIELD value
RETURN value.paths
```

## all shortest paths between two nodes + consider redirects as target

```sql
MATCH (source:page|redirect {title: "Gandalf"})
MATCH (target:page|redirect {title: "Ubuntu"})
OPTIONAL MATCH (redirects:redirect)-[:redirect_to]->(target)
CALL (source, target) {
  MATCH path = SHORTESTPATH((source)-[:link_to|redirect_to*1..100]->(target))
  RETURN length(path) AS len
}
CALL
  apoc.cypher.run(
    "CALL (source, target, len, redirects) {
      MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1.." + len + "]->(target))
      RETURN paths
      UNION
      OPTIONAL MATCH paths = ALLSHORTESTPATHS((source)-[:link_to|redirect_to*1.." + len + "]->(redirects))
      RETURN paths
    }
    WITH paths, [node IN nodes(paths) | node.title] AS titles
    ORDER BY titles
    return paths",
    {source: source, target: target, len:len, redirects:redirects}
  )
YIELD value
WITH DISTINCT value.paths AS paths
// SKIP 0 LIMIT 10
RETURN paths
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

## orphan nodes (long running procedure)

```sql
CALL apoc.periodic.iterate(
  "MATCH (node:page) RETURN node",
  "WITH node
  WHERE NOT EXISTS ((node)-[:link_to]->())
  AND NOT EXISTS ((node)<-[:link_to|redirect_to]-())
  AND NOT EXISTS ((node)<-[:contains]-(:category {title: 'Redirects_to_Wiktionary'}))
  CREATE (orphan:orphan {
    id: node.pageId,
    title: node.title,
    type: labels(node)[0],
    createdAt: timestamp()
  })
  WITH orphan
  CALL apoc.log.info(
    apoc.text.format(
      'orphan id: %s  title: %s type: %s', [orphan.id, orphan.title, orphan.type]
    )
  )
  RETURN orphan",
  {batchSize: 100000, parallel: true}
)
YIELD batches, total
RETURN batches, total

// wait for procedure to finish
```

```sql
MATCH (orphan:orphan {type: "page"}) // or "redirect"
RETURN orphan
ORDER BY orphan.title
// SKIP 0 LIMIT 10
```

## batch delete

```sql
CALL
  apoc.periodic.iterate(
    "MATCH (orphan:orphan) RETURN orphan",
    "DETACH DELETE orphan",
    {batchSize: 100000, parallel: true}
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
// SKIP 0 LIMIT 10 // carefull, will hang your host
```
