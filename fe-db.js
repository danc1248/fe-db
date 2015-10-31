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
      Enum: 3,
      Table: 4
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
      gender: {
        type: Enum
        values: ["m", "f"]
      }
      hobbies: {
        type: Table
        target: "hobbies"
      }
    }
     */
    Schema = (function() {
      function Schema(schema1, database) {
        var field, mixed, ref;
        this.schema = schema1;
        this.database = database;
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

      Schema.prototype._getIndexes = function() {
        return this.indexes;
      };

      Schema.prototype._validateData = function(data) {
        var j, len, row;
        for (j = 0, len = data.length; j < len; j++) {
          row = data[j];
          this._validateRow(row);
        }
        return true;
      };

      Schema.prototype._validateRow = function(row, index) {
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
          this._validateField(row[field], this.schema[field], field);
        }
        return true;
      };

      Schema.prototype._validateField = function(unknown, schema, field) {
        var nested, table;
        if (schema.type === DataTypes.Number && $.type(unknown) === "number") {
          return true;
        }
        if (schema.type === DataTypes.String && $.type(unknown) === "string") {
          return true;
        }
        if (schema.type === DataTypes.Enum && schema.values.indexOf(unknown) !== -1) {
          return true;
        }
        if (schema.type === DataTypes.Table) {
          table = this.database.getTable(schema.target);
          nested = table._getSchema();
          if (nested._validateData(unknown)) {
            return true;
          }
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
          this.indexes[index] = this._addIndex(index);
        }
      }

      Table.prototype._getSchema = function() {
        return this.schema;
      };

      Table.prototype._addIndex = function(field) {
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
        i = this.indexes[field][value];
        return this.data[i];
      };

      Table.prototype._getData = function() {
        return this.data;
      };

      Table.prototype.query = function() {
        var c, q;
        switch (arguments.length) {
          case 0:
          case 1:
            c = new Comparison(null, "*", null);
            break;
          case 2:
            c = new Comparison(arguments[0], "=", arguments[1]);
            break;
          default:
            c = new Comparison(arguments[0], arguments[1], arguments[2]);
        }
        q = new Query(this, c);
        return q;
      };

      return Table;

    })();

    /*
    Query: a query executes a series of comparisons on a table and returns the matches
    its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
     */
    Query = (function() {
      function Query(table1, comparison) {
        this.table = table1;
        this.comparison = comparison;
        this.queryOrdering = null;
      }

      Query.prototype.orderBy = function(field, order) {
        if (order == null) {
          order = "ASC";
        }
        this.queryOrdering = new QueryOrdering(field, order);
        return this;
      };

      Query.prototype.execute = function(value) {
        var deferred;
        deferred = $.Deferred();
        setTimeout((function(_this) {
          return function() {
            var output, row;
            if (_this.comparison._isSingleOperation() && _this.table._hasIndex(_this.comparison._getField())) {
              row = _this.table.getByIndex(_this.field, value);
              output = [row];
            } else {
              output = _this.table._getData().filter(function(row) {
                return _this.comparison._compare(row, value);
              });
            }
            if (_this.queryOrdering) {
              output = _this.queryOrdering._sortResults(output);
            }
            return deferred.resolve(output);
          };
        })(this));
        return deferred.promise();
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
    Comparison: used by the query to see if a values meet the criteria
     */
    Comparison = (function() {
      function Comparison(field1, operation, value1) {
        this.field = field1;
        this.operation = operation;
        this.value = value1;
        this.operationFn = null;
        this.setOperation(this.operation);
      }

      Comparison.prototype._getField = function() {
        return this.field;
      };

      Comparison.prototype._isSingleOperation = function() {
        return this.operation === "=";
      };

      Comparison.prototype.setOperation = function(operation) {
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
      };

      Comparison.prototype._compare = function(row) {
        return this.operationFn(row[this.field], this.value);
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
