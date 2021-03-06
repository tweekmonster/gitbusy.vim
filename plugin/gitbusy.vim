let s:cmd = 'command! -nargs=* -complete=custom,gitbusy#branchlist %s call gitbusy#switch(<q-args>)'

execute printf(s:cmd, 'GitBusy')
if get(g:, 'gitbusy_short_command', 0)
  execute printf(s:cmd, 'GB')
endif

unlet! s:cmd

augroup gitbusy
  autocmd! BufEnter * call gitbusy#setup()
augroup END
