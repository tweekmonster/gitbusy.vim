command! -nargs=1 -complete=custom,gitbusy#branchlist GitBusy call gitbusy#switch(<q-args>)

augroup gitbusy
  autocmd! SessionLoadPost,VimEnter * call gitbusy#setup()
augroup END
