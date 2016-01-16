# fe-db

simple query language for a local database

```coffeescript
d = new FEDB.Database()
d.setTable("trees", {
  tree_id: Number
  family: String
  name: String
}, [
  { tree_id : 1, family: "test", name : "Fir" }
  { tree_id : 2, family: "test", name : "Pine" }
  { tree_id : 3, family: "nega", name : "Maple" }
]
)

d.getTable("trees")
.query("family", "=", "test")
.or("name", "=", "Maple")
.orderBy("tree_id", "DESC")
.execute()
.then (output)->
  console.log output  
```

# Private functions:

publicFunction
_internalFunction - used outside a class, but internally to this app
__privateFunction