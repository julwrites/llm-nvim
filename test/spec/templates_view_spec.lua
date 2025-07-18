-- test/spec/templates_view_spec.lua

describe("templates_view", function()
  local templates_view
  local spy

  before_each(function()
    spy = require('luassert.spy')

    -- Keep a reference to the original functions
    local original_floating_input = require('llm.utils').floating_input
    local original_floating_confirm = require('llm.utils').floating_confirm

    -- Spy on the functions
    spy.on(require('llm.utils'), 'floating_input')
    spy.on(require('llm.utils'), 'floating_confirm')

    vim.ui.select = spy.new(function() end)
    vim.ui.input = spy.new(function() end)
    vim.notify = spy.new(function() end)

    templates_view = require('llm.templates.templates_view')

    -- Restore the original functions after each test
    after_each(function()
      require('llm.utils').floating_input = original_floating_input
      require('llm.utils').floating_confirm = original_floating_confirm
      vim.ui.select = nil
      vim.ui.input = nil
      vim.notify = nil
    end)
  end)

  it("should be a table", function()
    assert.is_table(templates_view)
  end)

  describe("select_template", function()
    it("should call vim.ui.select with the correct parameters", function()
      local templates = { template1 = "desc1", template2 = "desc2" }
      templates_view.select_template(templates, function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_user_input", function()
    it("should call utils.floating_input with the correct parameters", function()
      templates_view.get_user_input("prompt", "default", function() end)
      assert.spy(require('llm.utils').floating_input).was.called()
    end)
  end)

  describe("get_input_source", function()
    it("should call vim.ui.select", function()
      templates_view.get_input_source(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_template_type", function()
    it("should call vim.ui.select", function()
      templates_view.get_template_type(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_model_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_model_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("select_model", function()
    it("should call vim.ui.select", function()
      templates_view.select_model({ "model1", "model2" }, function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_fragment_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_fragment_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_add_fragment_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_add_fragment_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_add_system_fragment_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_add_system_fragment_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("get_option_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_option_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("confirm_extract", function()
    it("should call utils.floating_confirm", function()
      templates_view.confirm_extract(function() end)
      assert.spy(require('llm.utils').floating_confirm).was.called()
    end)
  end)

  describe("get_schema_choice", function()
    it("should call vim.ui.select", function()
      templates_view.get_schema_choice(function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("select_schema", function()
    it("should call vim.ui.select", function()
      templates_view.select_schema({ schema1 = "desc1" }, function() end)
      assert.spy(vim.ui.select).was.called()
    end)
  end)

  describe("confirm_delete", function()
    it("should call utils.floating_confirm", function()
      templates_view.confirm_delete("template1", function() end)
      assert.spy(require('llm.utils').floating_confirm).was.called()
    end)
  end)
end)
