
Main = require "../src/main.coffee"
Schema = require "../src/schema.coffee"

describe __filename, ->

  schemaObj =
    # basic data types:
    id: Main.DataTypes.Number
    name: Main.DataTypes.String
    table: Main.DataTypes.Table
    table2:
      type: Main.DataTypes.Table
      tableName: "tableName2"
    image: Main.DataTypes.Image

    # indexes:
    unique:
      type: Main.DataTypes.Number
      unique: true
    unique2:
      type: Main.DataTypes.String
      unique: true

  ignore = new Main.Database()
  schema = new Schema(schemaObj, ignore)

  describe "_getType", ->
    it "should know the id type", ->   expect(schema._getType("id")).toEqual(Main.DataTypes.Number)
    it "should know the name type", -> expect(schema._getType("name")).toEqual(Main.DataTypes.String)
    it "should know the id table", ->  expect(schema._getType("table")).toEqual(Main.DataTypes.Table)
    it "should know the id table2", -> expect(schema._getType("table2")).toEqual(Main.DataTypes.Table)
    it "should know the id image", ->  expect(schema._getType("image")).toEqual(Main.DataTypes.Image)
    it "should know the id unique", -> expect(schema._getType("unique")).toEqual(Main.DataTypes.Number)

  describe "_getTableName", ->
    it "should use the field as the defautl table name", -> expect(schema._getTableName("table")).toEqual("table")

    it "should get the defined table name", -> expect(schema._getTableName("table2")).toEqual("tableName2")

  describe "_getIndexes", ->
    it "should return our indexes", -> expect(schema._getIndexes()).toEqual(["unique", "unique2"])

  describe "__validateField", ->
    localSchemaObj =
      number: {type: Main.DataTypes.Number, required: true }
      string: {type: Main.DataTypes.String, required: true }
      table:  {type: Main.DataTypes.Table,  required: true }
      image:  {type: Main.DataTypes.Image,  required: true }

      required: { type: Main.DataTypes.Number, required: true }
      optional: { type: Main.DataTypes.Number, required: false }

    it "should accept numbers", ->
      expect(schema.__validateField(1, localSchemaObj.number, "number")).toBe(true)
    it "should reject non numbers", -> 
      expect(-> schema.__validateField("1", localSchemaObj.number, "number")).toThrow()

    it "should accept strings", -> 
      expect(schema.__validateField("1", localSchemaObj.string, "string")).toBe(true)
    it "should reject non strings", ->
      expect(-> schema.__validateField(1, localSchemaObj.string, "string")).toThrow()

    it "should accept tables", ->
      expect(schema.__validateField(["id"], localSchemaObj.table, "table")).toBe(true)
    it "should reject non tables", ->
      expect(-> schema.__validateField(1, localSchemaObj.table, "table")).toThrow()

    it "should accept airtable images"
    it "should reject non airtable images"

    it "should complain about missing required fields", ->
      expect(-> schema.__validateField(undefined, localSchemaObj.required, "ignore")).toThrow()
    it "should not complain about optional fields", ->
      expect(schema.__validateField(undefined, localSchemaObj.optional, "optional")).toBe(true)

