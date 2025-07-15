-- test/spec/utils_spec.lua

describe("llm.utils.validate", function()
  local validate = require("llm.utils.validate")

  describe("convert", function()
    it("should convert string to boolean", function()
      assert.are.same(true, validate.convert("true", "boolean"))
      assert.are.same(false, validate.convert("false", "boolean"))
    end)

    it("should convert number to boolean", function()
      assert.are.same(true, validate.convert(1, "boolean"))
      assert.are.same(false, validate.convert(0, "boolean"))
    end)

    it("should convert string to number", function()
      assert.are.same(123, validate.convert("123", "number"))
      assert.are.same(0, validate.convert("abc", "number"))
    end)

    it("should convert boolean to number", function()
      assert.are.same(1, validate.convert(true, "number"))
      assert.are.same(0, validate.convert(false, "number"))
    end)

    it("should convert to string", function()
      assert.are.same("123", validate.convert(123, "string"))
      assert.are.same("true", validate.convert(true, "string"))
    end)
  end)

  describe("validate", function()
    it("should validate basic types", function()
      assert.is_true(validate.validate("hello", "string"))
      assert.is_false(validate.validate(123, "string"))
      assert.is_true(validate.validate(123, "number"))
      assert.is_true(validate.validate(true, "boolean"))
      assert.is_true(validate.validate({}, "table"))
    end)

    it("should handle nil values", function()
      assert.is_true(validate.validate(nil, "string"))
    end)

    it("should handle 'any' type", function()
      assert.is_true(validate.validate("hello", "any"))
      assert.is_true(validate.validate(123, "any"))
    end)
  end)
end)
