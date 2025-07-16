dofile('test/init.lua')

package.path = package.path .. ';./test/plenary.nvim/lua/?.lua'
package.path = package.path .. ';./test/plenary.nvim/lua/?/init.lua'
package.path = package.path .. ';./lua/?.lua'
package.path = package.path .. ';./lua/?/init.lua'

local files = {
  'test/spec/simple_spec.lua',
  'test/spec/generate_models_list_spec.lua',
  'test/spec/models_manager_spec.lua',
  'test/spec/utils_spec.lua'
}

for _, file in ipairs(files) do
  require('plenary.busted').run(file)
end
