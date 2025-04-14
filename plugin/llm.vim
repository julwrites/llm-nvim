" llm.vim - Neovim plugin for simonw/llm
" Maintainer: julwrites
" Version: 0.1
" License: Apache 2.0

if exists('g:loaded_llm') || &cp || v:version < 700
  finish
endif
let g:loaded_llm = 1

" Ensure the Lua module is loaded
lua require('llm')

" Default configuration
if !exists('g:llm_model')
  let g:llm_model = ''  " Default to using the default model
endif

if !exists('g:llm_system_prompt')
  let g:llm_system_prompt = ''  " Default to no system prompt
endif

" Commands
command! -nargs=1 -range LLM call llm#prompt(<q-args>)
command! -nargs=? -range LLMWithSelection call llm#prompt_with_selection(<q-args>)
command! -nargs=? LLMChat lua require('llm').start_chat(<q-args>)
command! -nargs=? LLMExplain lua require('llm').explain_code()

" Key mappings (can be customized by user)
nnoremap <silent> <Plug>(llm-prompt) :LLM<Space>
vnoremap <silent> <Plug>(llm-selection) :LLMWithSelection<Space>
nnoremap <silent> <Plug>(llm-explain) :LLMExplain<CR>
nnoremap <silent> <Plug>(llm-chat) :LLMChat<CR>

" Default mappings (can be disabled with let g:llm_no_mappings = 1)
if !exists('g:llm_no_mappings')
  nmap <leader>llm <Plug>(llm-prompt)
  vmap <leader>llm <Plug>(llm-selection)
  nmap <leader>lle <Plug>(llm-explain)
  nmap <leader>llc <Plug>(llm-chat)
endif
