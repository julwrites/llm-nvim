-- require('spec_helper')

-- describe('llm.ui.views.schemas_view', function()
--   local schemas_view = require('llm.ui.views.schemas_view')
--   local ui = require('llm.core.utils.ui')

--   before_each(function()
--     vim.ui = {}
--   end)

--   describe('select_schema()', function()
--     it('should call vim.ui.select', function()
--       vim.ui.select = spy.new(function() end)
--       local schemas = {
--         { name = 'b', description = 'desc b' },
--         { name = 'a', description = 'desc a' }
--       }
--       schemas_view.select_schema(schemas, function() end)
--       assert.spy(vim.ui.select).was.called()
--     end)

--     it('should notify if no schemas are found', function()
--       vim.notify = spy.new(function() end)
--       schemas_view.select_schema({}, function() end)
--       assert.spy(vim.notify).was.called_with('No schemas found', vim.log.levels.INFO)
--     end)
--   end)

--   describe('get_schema_type()', function()
--     it('should call vim.ui.select', function()
--       vim.ui.select = spy.new(function() end)
--       schemas_view.get_schema_type(function() end)
--       assert.spy(vim.ui.select).was.called()
--     end)
--   end)

--   describe('get_input_source()', function()
--     it('should call vim.ui.select', function()
--       vim.ui.select = spy.new(function() end)
--       schemas_view.get_input_source(function() end)
--       assert.spy(vim.ui.select).was.called()
--     end)
--   end)

--   describe('get_url()', function()
--     it('should call ui.floating_input', function()
--       ui.floating_input = spy.new(function() end)
--       schemas_view.get_url(function() end)
--       assert.spy(ui.floating_input).was.called()
--     end)
--   end)

--   describe('get_schema_name()', function()
--     it('should call ui.floating_input', function()
--       ui.floating_input = spy.new(function() end)
--       schemas_view.get_schema_name(function() end)
--       assert.spy(ui.floating_input).was.called()
--     end)
--   end)

--   describe('get_schema_format()', function()
--     it('should call ui.floating_confirm', function()
--       ui.floating_confirm = spy.new(function() end)
--       schemas_view.get_schema_format(function() end)
--       assert.spy(ui.floating_confirm).was.called()
--     end)
--   end)

--   describe('get_alias()', function()
--     it('should call ui.floating_input', function()
--       ui.floating_input = spy.new(function() end)
--       schemas_view.get_alias(nil, function() end)
--       assert.spy(ui.floating_input).was.called()
--     end)
--   end)

--   describe('confirm_delete_alias()', function()
--     it('should call ui.floating_confirm', function()
--       ui.floating_confirm = spy.new(function() end)
--       schemas_view.confirm_delete_alias('test', function() end)
--       assert.spy(ui.floating_confirm).was.called()
--     end)
--   end)
-- end)
