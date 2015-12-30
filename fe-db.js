(function() {
  window.FEDB = (function() {
    var Comparison, DataTypes, Database, Query, QueryOrdering, Schema, Table;
    if (!$) {
      throw new Error("jQuery is required for promises");
    }

    /*
    Constants for representing datatypes for validation, etc.
     */
    DataTypes = {
      Number: 1,
      String: 2,
      Table: 4,
      Image: 5
    };

    /*
    Database: holds our tables, usage:
    d = new Database()
    d.setTable("trees", schema, sample_data)
    d.getTable("trees").query(...).execute().then (results)->
      do stuff
     */
    Database = (function() {
      function Database() {
        this.tables = {};
      }

      Database.prototype.setTable = function(name, schemaObj, data) {
        var schema;
        if (data == null) {
          data = [];
        }
        schema = new Schema(schemaObj, this);
        this.tables[name] = new Table(schema, data);
        return this;
      };

      Database.prototype.getTable = function(name) {
        if (this.tables[name] === void 0) {
          throw new Error("Unknown table: " + name);
        } else {
          return this.tables[name];
        }
      };

      return Database;

    })();

    /*
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
     */
    Schema = (function() {
      function Schema(schema1, database1) {
        var field, mixed, ref;
        this.schema = schema1;
        this.database = database1;
        this.indexes = [];
        ref = this.schema;
        for (field in ref) {
          mixed = ref[field];
          if ($.type(mixed) !== "object") {
            this.schema[field] = {
              type: mixed
            };
          } else {
            if (mixed.unique === true) {
              this.indexes.push(field);
            }
          }
        }
        this.fields = Object.keys(this.schema);
      }

      Schema.prototype._getType = function(field) {
        var obj;
        obj = this.schema[field];
        if (obj === void 0) {
          throw new Error("Unknown type: " + field);
        } else {
          return obj.type;
        }
      };

      Schema.prototype._getTableName = function(field) {
        var obj;
        obj = this.schema[field];
        if (obj === void 0 || obj.tableName === void 0) {
          throw new Error("Unknown table name: " + field);
        } else {
          return obj.tableName;
        }
      };

      Schema.prototype._getIndexes = function() {
        return this.indexes;
      };

      Schema.prototype._validateData = function(data) {
        var j, len, row;
        for (j = 0, len = data.length; j < len; j++) {
          row = data[j];
          this.__validateRow(row);
        }
        return true;
      };

      Schema.prototype.__validateRow = function(row, index) {
        var field, j, len, ref;
        if (this.fields.length !== Object.keys(row).length) {
          throw new Error("unmatched field count for row: " + index);
        }
        ref = this.fields;
        for (j = 0, len = ref.length; j < len; j++) {
          field = ref[j];
          if (row[field] === void 0) {
            throw new Error("Row not found: " + field + " at " + index);
          }
          this.__validateField(row[field], this.schema[field], field);
        }
        return true;
      };

      Schema.prototype.__validateField = function(unknown, schema, field) {
        if (schema.type === DataTypes.Number && $.type(unknown) === "number") {
          return true;
        }
        if (schema.type === DataTypes.String && $.type(unknown) === "string") {
          return true;
        }
        if (schema.type === DataTypes.Table && $.type(unknown) === "array") {
          if (schema.tableName === void 0) {
            schema.tableName = field;
          }
          return true;
        }
        if (schema.type === DataTypes.Image && $.type(unknown) === "object") {
          return true;
        }
        throw new Error("invalid type in data: " + field + ": " + unknown);
      };

      return Schema;

    })();

    /*
    Tables: hold our data and schema
    run queries on the table, or do a direct lookup using getByIndex
     */
    Table = (function() {
      function Table(schema1, data1) {
        var index, j, len, ref;
        this.schema = schema1;
        this.data = data1;
        this.schema._validateData(this.data);
        this.indexes = {};
        ref = this.schema._getIndexes();
        for (j = 0, len = ref.length; j < len; j++) {
          index = ref[j];
          this.indexes[index] = this.__addIndex(index);
        }
      }

      Table.prototype._getSchema = function() {
        return this.schema;
      };

      Table.prototype.__addIndex = function(field) {
        var i, index, j, len, ref, row;
        index = {};
        ref = this.data;
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          row = ref[i];
          if (index[row[field]] === void 0) {
            index[row[field]] = i;
          } else {
            throw new Error("non unique index: " + field);
          }
        }
        return index;
      };

      Table.prototype._hasIndex = function(field) {
        return !!this.indexes[field];
      };

      Table.prototype.getByIndex = function(field, value) {
        var i;
        if (this.indexes[field] !== void 0 && this.indexes[field][value] !== void 0) {
          i = this.indexes[field][value];
          return this.data[i];
        } else {
          throw new Error("getByIndex called on non-indexed field: " + field + ", " + value);
        }
      };

      Table.prototype._getData = function() {
        return this.data;
      };

      Table.prototype.query = function() {
        var q;
        q = new Query(this);
        return q;
      };

      return Table;

    })();

    /*
    Query: a query executes a series of comparisons on a table and returns the matches
    its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
     */
    Query = (function() {
      function Query(table1) {
        this.table = table1;
        this.comparison = null;
        this.queryOrdering = null;
        this.join = null;
      }

      Query.prototype.where = function(field, operator) {
        var c;
        c = new Comparison(field, operator);
        return this.setComparison(c);
      };

      Query.prototype.orderBy = function(field, order) {
        var qo;
        if (order == null) {
          order = "ASC";
        }
        qo = new QueryOrdering(field, order);
        return this.setQueryOrdering(qo);
      };

      Query.prototype.leftJoin = function(field, database, tableName) {
        var q, table;
        if (tableName == null) {
          tableName = null;
        }
        if (this.table._getSchema()._getType(field) === DataTypes.Table) {
          if (tableName === null) {
            tableName = this.table._getSchema()._getTableName(field);
          }
          table = database.getTable(tableName);
          q = table.query().where("id", "=");
          return this.setJoin(field, q);
        } else {
          throw new Error("Join only supported for DataType.Table: " + field);
        }
      };

      Query.prototype.setComparison = function(comparison) {
        if (this.comparison === null) {
          this.comparison = comparison;
        } else {
          throw new Error("Comparison already set");
        }
        return this;
      };

      Query.prototype.setQueryOrdering = function(queryOrdering) {
        if (this.queryOrdering === null) {
          this.queryOrdering = queryOrdering;
        } else {
          throw new Error("QueryOrdering already set");
        }
        return this;
      };

      Query.prototype.setJoin = function(field, query) {
        if (this.join === null) {
          this.join = {
            field: field,
            query: query
          };
        } else {
          throw new Error("Join already set, your dev is lazy and you cant do multiple joins");
        }
        return this;
      };

      Query.prototype.execute = function(value) {
        var deferred;
        deferred = $.Deferred();
        setTimeout((function(_this) {
          return function() {
            return deferred.resolve(_this.__execute(value));
          };
        })(this));
        return deferred.promise();
      };

      Query.prototype.__execute = function(value) {
        var field, joinField, joinQuery, results, row;
        if (this.comparison !== null) {
          field = this.comparison._getField();
          if (this.comparison._isSingleOperation() && this.table._hasIndex(field)) {
            row = this.table.getByIndex(field, value);
            results = [row];
          } else {
            results = this.table._getData().filter((function(_this) {
              return function(row) {
                return _this.comparison._compare(row, value);
              };
            })(this));
          }
        } else {
          results = JSON.parse(JSON.stringify(this.table._getData()));
        }
        if (this.join !== null) {
          joinField = this.join.field;
          joinQuery = this.join.query;
          results = results.map((function(_this) {
            return function(row) {
              var joinIds;
              joinIds = row[joinField];
              row[joinField] = joinIds.map(function(id) {
                results = joinQuery.__execute(id)[0];
                return results;
              });
              return row;
            };
          })(this));
        }
        if (this.queryOrdering !== null) {
          results = this.queryOrdering._sortResults(results);
        }
        return results;
      };

      return Query;

    })();

    /*
    For ordering queries, to keep the query object neater
     */
    QueryOrdering = (function() {
      function QueryOrdering(field, order) {
        switch (order) {
          case "ASC":
          case "asc":
            this.orderByFn = function(a, b) {
              var aVal, bVal;
              aVal = a[field];
              bVal = b[field];
              if (aVal < bVal) {
                return -1;
              } else if (aVal > bVal) {
                return 1;
              } else {
                return 0;
              }
            };
            break;
          case "DESC":
          case "desc":
            this.orderByFn = function(a, b) {
              var aVal, bVal;
              aVal = a[field];
              bVal = b[field];
              if (aVal < bVal) {
                return 1;
              } else if (aVal > bVal) {
                return -1;
              } else {
                return 0;
              }
            };
            break;
          default:
            throw new Error("unknown ordering: " + order);
        }
      }

      QueryOrdering.prototype._sortResults = function(results) {
        return results.sort(this.orderByFn);
      };

      return QueryOrdering;

    })();

    /*
    Comparison: used by the query to see if a row should be included in the search results
     */
    Comparison = (function() {
      function Comparison(field1, operation) {
        this.field = field1;
        this.operation = operation;
        switch (this.operation) {
          case "=":
            this.operationFn = function(a, b) {
              return a === b;
            };
            break;
          case "<>":
          case "!=":
            this.operationFn = function(a, b) {
              return a !== b;
            };
            break;
          case "<":
            this.operationFn = function(a, b) {
              return a < b;
            };
            break;
          case ">":
            this.operationFn = function(a, b) {
              return a > b;
            };
            break;
          case "<=":
            this.operationFn = function(a, b) {
              return a <= b;
            };
            break;
          case ">=":
            this.operationFn = function(a, b) {
              return a >= b;
            };
            break;
          case "*":
            this.operationFn = function() {
              return true;
            };
            break;
          default:
            throw new Error("operation not supported: " + this.operation);
        }
        return;
      }

      Comparison.prototype._getField = function() {
        return this.field;
      };

      Comparison.prototype._isSingleOperation = function() {
        return this.operation === "=";
      };

      Comparison.prototype._compare = function(row, value) {
        return this.operationFn(row[this.field], value);
      };

      return Comparison;

    })();
    return {
      Database: Database,
      Table: Table,
      Query: Query,
      Comparison: Comparison,
      Data: DataTypes
    };
  })();

}).call(this);
