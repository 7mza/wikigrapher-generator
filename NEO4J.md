# neo4j

some queries to start testing

### top/bottom N categories

```sql
MATCH (category:category)<-[:belong_to]-()
WITH category, count(*) AS categoryCount
RETURN category.title AS categoryTitle, categoryCount
ORDER BY categoryCount DESC // or ASC for bottom
LIMIT 3 // carefull, will hang your host
```

### shortest path between two nodes

```sql
MATCH path = SHORTESTPATH((source:page {title: "Gandalf"})-[:link_to|redirect_to*1..100]->(target:page|redirect {title: "Ubuntu"}))
RETURN path
```

### all shortest paths between two nodes

```sql
MATCH path = ALLSHORTESTPATHS((source:page {title: "Gandalf"})-[:link_to|redirect_to*1..100]->(target:page|redirect {title: "Ubuntu"}))
// WITH path SKIP 0 LIMIT 10
RETURN path
```

### all shortest paths between two nodes + categories of each node

```sql
MATCH paths = ALLSHORTESTPATHS((source:page {title: "Gandalf"})-[:link_to|redirect_to*1..100]->(target:page|redirect {title: "Ubuntu"}))
// WITH paths SKIP 0 LIMIT 10
UNWIND nodes(paths) AS nodes
OPTIONAL MATCH belongs = (nodes)-[:belong_to]->(categories:category)
RETURN paths, nodes, belongs, categories
```

### all categories of all shortest paths between two nodes

```sql
MATCH paths = ALLSHORTESTPATHS((source:page {title: "Gandalf"})-[:link_to|redirect_to*1..100]->(target:page|redirect {title: "Ubuntu"}))
// WITH paths SKIP 0 LIMIT 10
UNWIND nodes(paths) AS nodes
OPTIONAL MATCH belongs = (nodes)-[:belong_to]->(categories:category)
RETURN COLLECT(DISTINCT categories)
```

### orphan pages (long running procedure)

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

### batch delete

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

### all nodes belonging to a category

```sql
MATCH (node)-[:belong_to]->(:category {title: "The_Lord_of_the_Rings_characters"})
RETURN node
ORDER BY node.title
SKIP 0
LIMIT 10 // carefull, will hang your host
```
