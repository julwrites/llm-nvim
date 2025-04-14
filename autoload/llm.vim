" autoload/llm.vim - Autoloaded functions for llm plugin
" License: Apache 2.0

" Function to send a prompt to llm
function! llm#prompt(prompt) abort
  call luaeval('require("llm").prompt(_A)', a:prompt)
endfunction

" Function to send selected text with a prompt to llm
function! llm#prompt_with_selection(prompt) abort
  call luaeval('require("llm").prompt_with_selection(_A)', a:prompt)
endfunction
