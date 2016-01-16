
QueryOrdering = require "../src/queryOrdering.coffee"

describe __filename, ->

  it "should sort data asc by field", ->
    queryOrdering = new QueryOrdering("id", "asc")

    expect(queryOrdering._sortResults([{id: 2}, {id: 1}])).toEqual([{id:1}, {id:2}])

  it "should sort data desc by field", ->
    queryOrdering = new QueryOrdering("id", "desc")

    expect(queryOrdering._sortResults([{id: 1}, {id: 2}])).toEqual([{id: 2}, {id:1}])

  it "can also sort strings", ->
    queryOrdering = new QueryOrdering("id", "asc")

    expect(queryOrdering._sortResults([{id: "b"}, {id: "a"}])).toEqual([{id: "a"}, {id:"b"}])