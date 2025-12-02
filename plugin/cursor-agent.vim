" ====================================================================
" cursor-agent.vim
" Send visual selection (if any) to cursor-agent in a new vertical iTerm2 pane
" ====================================================================

" Helper: get selected range ONLY if there is a real visual selection
function! s:GetRangeAndText()
  let l:start = line("'<")
  let l:end   = line("'>")

  " Detect real visual selection (lines differ OR columns differ)
  if l:start > 0 && l:end > 0 && (l:start != l:end || col("'<") != col("'>"))
    let l:lines = getline(l:start, l:end)
    let l:text  = join(l:lines, "\n")

    " Trim trailing blank lines
    while l:text =~# '\n\s*$'
      let l:text = substitute(l:text, '\n\s*$', '', '')
    endwhile

    return [l:start, l:end, l:text]
  endif

  " No selection
  return ['', '', '']
endfunction


function! CursorAgentSend()
  " ------------------------------------------------------------
  " 1. Metadata: filename + lines (only if selection exists)
  " ------------------------------------------------------------
  let [l:start, l:end, l:text] = s:GetRangeAndText()
  let l:has_selection = (l:start !=# '' && l:end !=# '' && l:text !=# '')

  " Full path of current file
  let l:file = expand('%:p')

  " Auto detect git root
  let l:project_root = substitute(system('git rev-parse --show-toplevel'), '\n', '', '')

  " If not a git repo, fallback to file directory
  if empty(l:project_root)
    let l:project_root = expand('%:p:h')
  endif

  " Default: no payload
  let l:payload = ''

  if l:has_selection
    " Relative path (strip project root)
    let l:relfile = substitute(l:file, '^' . l:project_root . '/', '', '')

    " Range
    if l:start == l:end
      let l:range = l:start
    else
      let l:range = l:start . '-' . l:end
    endif

    " Cursor-style header
    let l:header = '@' . l:relfile . ':' . l:range

    " Escape header for AppleScript string
    let l:payload = substitute(l:header, '"', '\\\"', 'g')
  endif

  " ------------------------------------------------------------
  " 2. Build AppleScript
  " ------------------------------------------------------------
  let l:script = [
  \ 'tell application "iTerm2"',
  \ '  tell current window',
  \ '    tell current session',
  \ '      set newPane to (split vertically with profile "Default")',
  \ '    end tell',
  \ '    tell newPane',
  \ '      write text "cd ' . l:project_root . '"',
  \ '      delay 0.2',
  \ '      write text "cursor-agent"',
  \ '      delay 0.5'
  \ ]

  " Add header ONLY if we actually have a visual selection
  if l:payload !=# ''
    call add(l:script, '      write text "' . l:payload . '"')
  endif

  " Close AppleScript
  call extend(l:script, [
  \ '    end tell',
  \ '  end tell',
  \ 'end tell'
  \ ])

  " ------------------------------------------------------------
  " 3. Save to temp file and execute
  " ------------------------------------------------------------
  let l:tmp = tempname()
  call writefile(l:script, l:tmp)
  call system('osascript ' . shellescape(l:tmp))
  call delete(l:tmp)
endfunction


" ====================================================================
" COMMAND + MAPPINGS
" ====================================================================
command! CursorAsk call CursorAgentSend()

" Run from normal mode
nnoremap <silent> <leader>ca :CursorAsk<CR>

" Run from visual mode (keep <'> marks)
xnoremap <silent> <leader>ca :<C-u>CursorAsk<CR>

" Run from insert mode (escape first)
inoremap <silent> <leader>ca <Esc>:CursorAsk<CR>
