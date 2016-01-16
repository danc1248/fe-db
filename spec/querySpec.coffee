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
      { id: 1, name: "one" }
      { id: 2, name: "two" }
      { id: 3, name: "three" }
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
      expect(query.where("id", "=").__execute(2)).toEqual([{ id: 2, name: "two"}])
      expect(database.getTable("trees").getByIndex).toHaveBeenCalled()

    it "should return the 2nd row found by a non-index", ->
      spyOn(database.getTable("trees"), "getByIndex").and.callThrough()
      expect(query.where("name", "=").__execute("two")).toEqual([{ id: 2, name: "two"}])
      expect(database.getTable("trees").getByIndex).not.toHaveBeenCalled()

  describe "orderBy", ->
    it "should sort apply the sort in the results when returing all", ->
      results = query.orderBy("name", "desc").__execute()
      expect(results[0]).toEqual({ id: 2, name: "two"})

      # it should not have changed the original data order
      expect(database.getTable("trees")._getData()[0]).toEqual({ id: 1, name: "one"})

    it "should sort apply the sort in the results using where", ->
      results = query.where("id", "<=").orderBy("name", "desc").__execute(2)
      expect(results[0]).toEqual({ id: 2, name: "two"})

      # it should not change the original data:
      expect(database.getTable("trees")._getData()[0]).toEqual({ id: 1, name: "one"})

  describe "leftJoin", ->
    it "should return our joined data of course!", ->
      results = database.getTable("group").query().leftJoin("trees", database).__execute()
      expect(results[0].id).toBe(1)
      expect(results[0].trees[0].id).toBe(1)
      expect(results[0].trees[1].id).toBe(3)

      expect(results[1].id).toBe(2)
      expect(results[1].trees[0].id).toBe(2)

      expect(results[2].trees.length).toBe(0)

      # and original data is the same
      expect(database.getTable("group")._getData()[0].trees).toEqual([1, 3])


