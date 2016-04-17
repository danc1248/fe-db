
Comparison = require "../src/comparison.coffee"

sampleRow = { id: 4 };

describe __filename, ->

  describe "=", ->
    comparison = new Comparison("id", "=")
    it "should return the field", -> expect(comparison._getField()).toEqual("id")
    it "should be a single operation", -> expect(comparison._isSingleOperation()).toBe(true)
    it "should filter", -> expect(comparison._compare(sampleRow, 4)).toBe(true)
    it "should filter negative", -> expect(comparison._compare(sampleRow), 5).toBe(false)


  describe "<>", ->
    comparison = new Comparison("id", "<>")
    it "should not be a single operation", -> expect(comparison._isSingleOperation()).toBe(false)
    it "should filter", -> expect(comparison._compare(sampleRow, 100)).toBe(true)
    it "should filter negative", -> expect(comparison._compare(sampleRow, 4)).toBe(false)

  describe "in", ->
    comparison = new Comparison("id", "in")
    it "should return the thing", -> expect(comparison._compare(sampleRow, [1,4,6])).toBe(true)
    it "should return the neg", ->   expect(comparison._compare(sampleRow, [1,6])).toBe(false)

  # I'm not going to write a test for each comparison function...