
Table = require "../src/table.coffee"
Schema = require "../src/schema.coffee"
DataTypes = require "../src/datatypes.coffee"
Query = require "../src/query.coffee"

describe __filename, ->

  schema = new Schema({
    id:
      type: DataTypes.Number
      unique: true
    normal: 
      type: DataTypes.Number
      required: false
  })

  data = [
    { id: 1, normal: 1 }
    { id: 2, normal: 2 }
  ]

  table = new Table(schema, data)

  describe "_hasIndex", ->
    it "should know that the field is indexed", -> expect(table._hasIndex("id")).toBe(true)
    it "should know the other field isnt indexed", -> expect(table._hasIndex("normal")).toBe(false)

  describe "getByIndex", ->
    it "should find the id using the unique id", -> expect(table.getByIndex("id", 1)).toEqual({ id: 1, normal: 1 })
    it "should complain about searching on a non-indexed field", -> expect(-> table.getByIndex("normal", 1)).toThrow()

  describe "unique", ->
    it "should complain about non-unique values", ->
      expect(-> new Table(schema, [{ id: 1 }, { id: 1 }])).toThrow()

  describe "query", ->
    it "should return a query object", -> expect(table.query().constructor).toEqual(Query)

  describe "_getData", ->
    it "should return our data, of course", -> expect(table._getData()).toEqual(data)




