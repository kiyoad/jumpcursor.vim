" jumpcursor.vim
" Author: skanehira
" License: MIT

" if exists('g:jumpcursor_marks')
"   unlet g:jumpcursor_marks
" endif
let g:jumpcursor_marks = get(g:, 'jumpcursor_marks', split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@[;:],./_-^\1234567890', '\zs'))

let s:jumpcursor_mark_lnums = {}
let s:jumpcursor_mark_cols = {}
let s:jumpcursor_ns = nvim_create_namespace('jumpcursor')

function! s:fill_window() abort
  let start_line = line('w0')
  let end_line = line('w$')
  let bufnr = bufnr()
  let mark_len = len(g:jumpcursor_marks)
  let current_line = line('.')
  let mark_start_line = current_line - (mark_len / 2)
  let mark_end_line = current_line + (mark_len / 2)

  if mark_end_line > end_line
    let mark_start_line -= (mark_end_line - end_line - 1)
  endif
  if start_line < mark_start_line
    let start_line = mark_start_line
  endif

  " [[1, 1], [1,2], [1,5]]
  let linecols = []
  let mark_idx = 0

  while start_line <= end_line
    if mark_idx >= mark_len
      break
    endif
    let text = getline(start_line)
    let mark = g:jumpcursor_marks[mark_idx]
    for i in range(len(text))
      " skip blank
      if text[i] ==# ' ' || text[i] ==# "\t"
        continue
      endif
      call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, start_line-1, i, {
            \ 'virt_text_pos': 'overlay',
            \ 'virt_text':
            \ [
              \ [mark, 'ErrorMsg']
            \ ]})

      call add(linecols, [start_line-1, i])
    endfor
    let s:jumpcursor_mark_lnums[mark] = start_line
    if len(text) > 0
      let mark_idx += 1
    endif
    let start_line += 1
  endwhile
endfunction

function! s:fill_specific_line(lnum) abort
  let text = getline(a:lnum)
  let bufnr = bufnr()
  let mark_idx = 0
  let mark_len = len(g:jumpcursor_marks)
  let word_head = 1
  let first_time = 1

  for i in range(len(text))
    if mark_idx >= mark_len
      break
    endif

    if text[i] ==# ' ' || text[i] ==# "\t"
      let word_head = 1
      continue
    elseif first_time == 0 && stridx('!"#$%&''()*+,-./:;<=>?[\]^_`{|}~', text[i]) >= 0
      " '!"#$%&''()*+,-./:;<=>?[\]^_`{|}~'
      let word_head = 1
      continue
    elseif word_head == 0
      continue
    else
      let word_head = 0
    endif

    let mark = g:jumpcursor_marks[mark_idx]
    let mark_idx += 1

    call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, a:lnum-1, i, {
          \ 'virt_text_pos': 'inline',
          \ 'virt_text':
          \ [
            \ [mark, 'ErrorMsg']
          \ ]})

    let s:jumpcursor_mark_cols[mark] = i
    let first_time = 0
  endfor
  redraw!
endfunction

function! jumpcursor#jump() abort
  call s:fill_window()
  redraw!

  let mark = getcharstr()
  call s:jump_cursor_clear()

  if mark ==# '' || mark ==# ' ' || !has_key(s:jumpcursor_mark_lnums, mark)
    return
  endif

  let lnum = s:jumpcursor_mark_lnums[mark]

  call s:fill_specific_line(lnum)

  let mark = getcharstr()
  call s:jump_cursor_clear()

  if mark ==# '' || mark ==# ' ' || !has_key(s:jumpcursor_mark_cols, mark)
    return
  endif

  let col = s:jumpcursor_mark_cols[mark] + 1

  call setpos('.', [bufnr(), lnum, col, 0])

  let s:jumpcursor_mark_lnums = {}
  let s:jumpcursor_mark_cols = {}
endfunction

function! s:jump_cursor_clear() abort
  call nvim_buf_clear_namespace(bufnr(), s:jumpcursor_ns, line('w0')-1, line('w$'))
endfunction
