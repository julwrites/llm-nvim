package = "app"
version = "dev-1"
source = {
   url = "git+https://github.com/julwrites/llm-nvim"
}
description = {
   detailed = "A Neovim plugin for integrating with [Simon Willison's llm CLI tool](https://github.com/simonw/llm).",
   homepage = "https://github.com/julwrites/llm-nvim",
   license = "*** please specify a license ***"
}
build = {
   type = "builtin",
   modules = {
      ["llm.api"] = "lua/llm/api.lua",
      ["llm.commands"] = "lua/llm/commands.lua",
      ["llm.config"] = "lua/llm/config.lua",
      ["llm.core.data.cache"] = "lua/llm/core/data/cache.lua",
      ["llm.core.data.llm_cli"] = "lua/llm/core/data/llm_cli.lua",
      ["llm.core.loaders"] = "lua/llm/core/loaders.lua",
      ["llm.core.utils.file_utils"] = "lua/llm/core/utils/file_utils.lua",
      ["llm.core.utils.notify"] = "lua/llm/core/utils/notify.lua",
      ["llm.core.utils.shell"] = "lua/llm/core/utils/shell.lua",
      ["llm.core.utils.text"] = "lua/llm/core/utils/text.lua",
      ["llm.core.utils.ui"] = "lua/llm/core/utils/ui.lua",
      ["llm.core.utils.validate"] = "lua/llm/core/utils/validate.lua",
      ["llm.errors"] = "lua/llm/errors.lua",
      ["llm.facade"] = "lua/llm/facade.lua",
      ["llm.init"] = "lua/llm/init.lua",
      ["llm.managers.custom_openai"] = "lua/llm/managers/custom_openai.lua",
      ["llm.managers.fragments_manager"] = "lua/llm/managers/fragments_manager.lua",
      ["llm.managers.keys_manager"] = "lua/llm/managers/keys_manager.lua",
      ["llm.managers.models_io"] = "lua/llm/managers/models_io.lua",
      ["llm.managers.models_manager"] = "lua/llm/managers/models_manager.lua",
      ["llm.managers.plugins_manager"] = "lua/llm/managers/plugins_manager.lua",
      ["llm.managers.schemas_manager"] = "lua/llm/managers/schemas_manager.lua",
      ["llm.managers.templates_manager"] = "lua/llm/managers/templates_manager.lua",
      ["llm.ui.styles"] = "lua/llm/ui/styles.lua",
      ["llm.ui.ui"] = "lua/llm/ui/ui.lua",
      ["llm.ui.unified_manager"] = "lua/llm/ui/unified_manager.lua",
      ["llm.ui.views.fragments_view"] = "lua/llm/ui/views/fragments_view.lua",
      ["llm.ui.views.keys_view"] = "lua/llm/ui/views/keys_view.lua",
      ["llm.ui.views.models_view"] = "lua/llm/ui/views/models_view.lua",
      ["llm.ui.views.plugins_view"] = "lua/llm/ui/views/plugins_view.lua",
      ["llm.ui.views.schemas_view"] = "lua/llm/ui/views/schemas_view.lua",
      ["llm.ui.views.templates_view"] = "lua/llm/ui/views/templates_view.lua"
   },
   copy_directories = {
      "doc",
      "tests"
   }
}
