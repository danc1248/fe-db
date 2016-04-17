# for the query spec, we are going to just run queries against mock data to make sure things work

Main = require "../src/main.coffee"

describe __filename, ->
  database = null
  query = null

  beforeEach ->
    database = new Main.Database()
    database.setTable "trees", {
      id:
        type: Main.DataTypes.Number
        unique: true
      name: Main.DataTypes.String
    }, [
      { id: 1, name: "one",   rank: 3 }
      { id: 2, name: "two",   rank: 2 }
      { id: 3, name: "three", rank: 1 }
    ]

    database.setTable "group", {
      id:
        type: Main.DataTypes.Number
        unique: true
      name: Main.DataTypes.String
      trees: Main.DataTypes.Table
    }, [
      { id: 1, name: "odd", trees: [1, 3] }
      { id: 2, name: "even", trees: [2] }
      { id: 3, name: "cray", trees: [] }
    ]

    query = new Main.Query(database.getTable("trees"))

  describe "where", ->
    
    it "should return the 2nd row found by index", ->
      spyOn(database.getTable("trees"), "getByIndex").and.callThrough()
      expect(query.where("id", "=").__execute(2)).toEqual([{ id: 2, name: "two", rank: 2 }])
      expect(database.getTable("trees").getByIndex).toHaveBeenCalled()

    it "should return the 2nd row found by a non-index", ->
      spyOn(database.getTable("trees"), "getByIndex").and.callThrough()
      expect(query.where("name", "=").__execute("two")).toEqual([{ id: 2, name: "two", rank: 2 }])
      expect(database.getTable("trees").getByIndex).not.toHaveBeenCalled()

  describe "orderBy", ->
    it "should sort apply the sort in the results when returing all", ->
      results = query.orderBy("name", "desc").__execute()
      expect(results[0]).toEqual({ id: 2, name: "two", rank: 2 })

      # it should not have changed the original data order
      expect(database.getTable("trees")._getData()[0]).toEqual({ id: 1, name: "one", rank: 3 })

    it "should sort apply the sort in the results using where", ->
      results = query.where("id", "<=").orderBy("name", "desc").__execute(2)
      expect(results[0]).toEqual({ id: 2, name: "two", rank: 2 })

      # it should not change the original data:
      expect(database.getTable("trees")._getData()[0]).toEqual({ id: 1, name: "one", rank: 3 })

  describe "leftJoin", ->
    it "should return our joined data of course!", ->
      results = database.getTable("group").query().leftJoin("trees", database).__execute()
      expect(results).toEqual([
        {
          id: 1
          name: "odd"
          trees: [
            { id: 1, name: "one", rank: 3 }
            { id: 3, name: "three", rank: 1 }
          ]
        }
        {
          id: 2
          name: "even"
          trees: [
            { id: 2, name: "two", rank: 2 }
          ]
        }
        {
          id: 3
          name: "cray"
          trees: []
        }
      ])
    
      # and original data is the same
      expect(database.getTable("group")._getData()[0].trees).toEqual([1, 3])

  # for doing some more complicated joins
  describe "join with order", ->
    it "should accept a separate join so you can do a query with order", ->
      joinQuery = (new Main.Query(database.getTable("trees"))).where("id", "in").orderBy("rank", "asc")
      results = database.getTable("group").query().where("id", "=").setJoin("trees", joinQuery).__execute(1)
      expect(results).toEqual([{
        id: 1
        name: "odd"
        trees: [
          { id: 3, name: "three", rank: 1 }
          { id: 1, name: "one",   rank: 3 }
        ]  
      }])

    it "same query except with shorthand", ->
      results = database.getTable("group").query().where("id", "=").leftJoin("trees", database, null, "rank", "asc").__execute(1)
      expect(results).toEqual([{
        id: 1
        name: "odd"
        trees: [
          { id: 3, name: "three", rank: 1 }
          { id: 1, name: "one",   rank: 3 }
        ]  
      }])


