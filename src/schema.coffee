###
Holds table schema and does some validation etc.
e.g.
{
  id: {
    type: Number
    unique: true <-- add a unique index
  }
  age: Number
  name: String
  text: {
    type: String
  }
  hobbies: {
    type: Table
    target: "hobbies"
  }
}
###

util = require "util"
DataTypes = require "./datatypes.coffee"

class Schema
  # this schema could be on a complete form that we want to save:
  # { id: { type: Number, ...other properties }, ... other fields}
  # or it could be simple: { id: Number } in which case we have to extend it
  # database, schemas can reference other tables, so we need to keep track of original calling database so we can grab those tables
  constructor: (@schema = {})->
    @indexes = []
    # look for simple enteries and extend them:
    for field, mixed of @schema
      type = Object.prototype.toString.call(mixed)
      if type isnt "[object Object]"
        @schema[field] = { type: mixed }

    # loop through the properties and do stuff:
    for field, properties of @schema

      # currently only support unique indexes, beware!
      if properties.unique is true
        @indexes.push field

      # set the default tableName to the field, if its not defined
      if properties.type is DataTypes.Table and properties.tableName is undefined
        properties.tableName = field

      # default required state is true
      if properties.required isnt true and properties.required isnt false
        properties.required = true

    @fields = Object.keys(@schema)

  # other classes sometimes want to poke in and see what the data type is:
  # @param: string field
  # @return: Datatypes.*
  _getType: (field)->
    obj = @schema[field]
    if obj is undefined
      throw new Error "Unknown type: #{field} in #{util.inspect(obj, false, null)}"
    else
      return obj.type

  # similarly, if you are joining on a table, you might want to lookup what its supposed to be joined on, as defined in the schema
  _getTableName: (field)->
    obj = @schema[field]
    if obj is undefined or obj.tableName is undefined
      throw new Error "Unknown table name: #{field} in #{util.inspect(obj, false, null)}"
    else
      return obj.tableName

  # this class knows which fields are indexed, but does not build or use them at all
  # building indexes is handled at the table level
  # @return : Array of String names of fields that have indexes
  _getIndexes: ->
    return @indexes

  # When data is added to a table, you can validate it using this function, this step is optional because if your data is static, you don't need to validate it all he time
  # @param: array of objects to validate against the schema
  # @return: boolean
  _validateData: (data)->
    for row in data
      @__validateRow(row)
    return true

  # validate a single object from the array
  __validateRow: (row)->
    for field, index in @fields
      @__validateField(row[field], @schema[field], "#{index}.#{field}")
    return true

  # validate a field from the single object
  # @param: mixed variable that we are validating
  # @param: object representing this field's schema
  # @param: string field name - ONLY FOR DEBUGGING
  # @return: boolean
  __validateField: (unknown, schema, field)->
    # oh no! there is no data: if the field is required, complain, otherwise peace out
    if unknown is undefined
      if schema.required is true
        throw new Error "undefined value for required field: #{field}"
      else
        return true

    unknownType = Object.prototype.toString.call(unknown)

    if schema.type is DataTypes.Number and unknownType is "[object Number]"
      return true

    if schema.type is DataTypes.String and unknownType is "[object String]"
      return true

    # this is based off of how airtable handles joins.  The field contains an array of string, which are their internal ID for the row at the table.  By convention, we are assuming that the name of he field is the same as the name of the table.
    if schema.type is DataTypes.Table and unknownType is "[object Array]"
      return true

    # @TODO: this is modeled after airtable's attachments and I'm not exactly sure how its going to be used
    if schema.type is DataTypes.Image and unknownType is "[object Array]"
      return true

    throw new Error "invalid type in data: #{field}: #{unknown}"

module.exports = Schema