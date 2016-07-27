let s:stderr = ''
let s:datadir = get(g:, 'gitbusy_datadir', '.gitbusy')

" This should be a sufficiently unique string in the stash message.
let s:key_prefix = '@@gitbusy@@'

if has('win32')
  let s:sep = '\'
  let s:sep_p = '\\'
else
  let s:sep = '/'
  let s:sep_p = '/'
endif

let s:orig_undodir = &undodir

unlet! s:_gitroot
unlet! s:_repo


" Strip trailing slash from string.
function! s:strip_slash(s) abort
  return substitute(a:s, s:sep_p.'\+$', '', 'g')
endfunction


" Normalize a path string.
function! s:path(path) abort
  return simplify(substitute(a:path, '/', s:sep, 'g'))
endfunction


" Append path components to a base path.  Always remove the trailing slash.
function! s:path_append(base, ...) abort
  return s:strip_slash(s:path(s:strip_slash(a:base).'/'.join(a:000, '/')))
endfunction


let s:shadafile = s:path_append(s:datadir, 'shada')
let s:hunkfile = s:path_append(s:datadir, 'staged_index')
let s:sessionfile = s:path_append(s:datadir, 'session.vim')
let s:undodir = s:path_append(s:datadir, 'undo')


" Strip whitespace surrounding string.
function! s:strip(s) abort
  return substitute(a:s, '\_^\_s\+\|\_s\+\_$', '', 'g')
endfunction


" Set relevant paths.
function! s:set_gitpaths() abort
  let output = system('git rev-parse --show-toplevel --git-dir')
  let lines = split(output, "\n")
  if v:shell_error || len(lines) < 2
    let s:_repo = ''
    let s:_gitroot = ''
    return
  endif

  let s:_repo = lines[0]
  let s:_gitroot = lines[1]
endfunction


" Get a file at the .git directory.
" We only care about the git dir and work tree for the files this script
" create.
function! s:gitroot(...) abort
  if !exists('s:_gitroot')
    call s:set_gitpaths()
  endif
  return call('s:path_append', [s:_gitroot] + a:000)
endfunction


" Naive test for a git repo.
function! s:is_git_repo() abort
  return filewritable(s:gitroot()) == 2
endfunction


" Get a file at the root of the repo work tree.
function! s:repo(...) abort
  if !exists('s:_repo')
    call s:set_gitpaths()
  endif
  return call('s:path_append', [s:_repo] + a:000)
endfunction


" Run a git command.  Returns the output, and stores stderr in s:stderr.
" Callers must rely on v:shell_error to check for errors.
function! s:git(...) abort
  let root = s:gitroot()
  let repo = s:repo()
  let args = join(map(['--git-dir='.root, '-C', repo] + copy(a:000), 'shellescape(v:val)'), ' ')
  let git = get(g:, 'gitbusy_git_exe', 'git')
  let stderr_file = tempname()
  let output = system(git.' '.args.' 2>'.stderr_file)
  let s:stderr = join(readfile(stderr_file), "\n")
  if v:shell_error
    return ''
  endif
  return output
endfunction


" Like s:git(), but prints errors
function! s:gite(...) abort
  let output = call('s:git', a:000)
  if v:shell_error
    echohl ErrorMsg
    echomsg s:stderr
    echohl None
  endif
  return output
endfunction


" Check and ensure that s:datadir is ignored and added to .git/info/exclude
function! s:check_exclusions() abort
  let exclude_file = s:gitroot('info/exclude')

  if filewritable(exclude_file)
    let lines = readfile(exclude_file)
    if empty(filter(copy(lines), 'v:val == s:datadir'))
      call add(lines, s:datadir)
      call writefile(lines, exclude_file)
    endif
    return 1
  endif

  return 0
endfunction


" Get a reproducible and unique name for a stash based on a branch.  Uses HEAD
" if a branch isn't supplied.
function! s:stash_key(...) abort
  let ref = a:0 ? a:1 : 'HEAD'
  let hash = s:strip(s:gite('rev-parse', '--short', ref))
  if v:shell_error || empty(hash)
    throw 'Could not create a stash key for: '.ref
  endif

  return s:key_prefix.hash
endfunction


" Find all gitbusy stashes.
function! s:all_stashes() abort
  let stash_pat = escape(s:key_prefix, '^$.[]').'\x\+$'
  let matches = []

  for line in split(s:git('stash', 'list', '--oneline', '--no-color'), "\n")
    if line =~# stash_pat
      " 05a92a2 refs/stash@{0}: On master: @@gitbusy@@291c3c6
      let stash_hash = matchstr(line, '[^ ]\+')
      let stash_id = matchstr(line, 'refs/\zsstash@.\{-}\ze:')
      let branch = matchstr(line, ': On \zs[^:]\+')
      let key = matchstr(line, stash_pat)
      call add(matches, [stash_hash, stash_id, branch, key])
    endif
  endfor

  return matches
endfunction


" Find a stashes matching the key.
function! s:find_stash(key) abort
  let matches = []

  for info in s:all_stashes()
    if info[-1] == a:key
      call add(matches, info)
    endif
  endfor

  return matches
endfunction


" Drop stashes matching hashes.  This is needed because `stash drop` requires
" the stash ID, but they can only be dropped one at a time and the ID is a
" consecutive sequence starting from 0.
function! s:drop_stashes(hashes) abort
  for hash in a:hashes
    for info in s:all_stashes()
      if info[0] == hash
        call s:gite('stash', 'drop', '-q', info[1])
        if v:shell_error
          return 0
        endif
      endif
    endfor
  endfor

  return 1
endfunction


" Save the current session.
function! s:save_session() abort
  let orig_sessopts = &sessionoptions
  set sessionoptions=buffers,curdir,folds,help,slash,tabpages,unix
  execute 'silent mksession!' s:repo(s:sessionfile)
  let &sessionoptions = orig_sessopts

  if get(g:, 'gitbusy_save_shada', 1)
    if has('nvim')
      let shadacmd = 'wshada'
    else
      let shadacmd = 'wviminfo'
    endif

    execute 'silent '.shadacmd.'! '.s:repo(s:shadafile)
  endif
endfunction


" Load the session and delete the session file.
function! s:load_session() abort
  let session_file = s:repo(s:sessionfile)
  if filereadable(session_file)
    execute 'silent source' session_file
    call delete(session_file)
  endif

  let shada_file = s:repo(s:shadafile)
  if filereadable(shada_file)
    if get(g:, 'gitbusy_save_shada', 1)
      if has('nvim')
        let shadacmd = 'rshada'
      else
        let shadacmd = 'rviminfo'
      endif

      execute 'silent '.shadacmd.'! '.s:repo(s:shadafile)
    endif
    call delete(shada_file)
  endif
endfunction


" Create a diff of the index (staged hunks).
function! s:save_staged_hunks() abort
  let staged = s:gite('diff', '--cached')
  if !v:shell_error
    if !empty(split(staged, "\n"))
      call writefile(split(staged, "\n", 1), s:repo(s:hunkfile))
    endif
    return 1
  endif
  return 0
endfunction


" Apply the diff of the index (staged hunks).
function! s:restore_staged_hunks() abort
  let hunk_file = s:repo(s:hunkfile)
  if filereadable(hunk_file)
    let output = s:gite('apply', '--cached', hunk_file)
    if !v:shell_error
      call delete(hunk_file)
      return 1
    endif
    return 0
  endif
  return 1
endfunction


" Stash the session.
function! s:stash(key) abort
  let datadir = s:repo(s:undodir)
  if filewritable(datadir) == 2
    call s:gite('add', '-f', s:datadir)
    if v:shell_error
      return
    endif
  endif

  call s:gite('stash', 'save', '-q', '--include-untracked', a:key)
  return v:shell_error == 0
endfunction


" Apply the stashed session and remove plugin files from the index.
function! s:unstash(key) abort
  let stashes = s:find_stash(a:key)
  if empty(stashes)
    return 0
  endif

  if len(stashes) > 1
    " There should only be one before we get here.  Throw an exception.
    throw 'Multiple stashes found matching "'.a:key.'".  This shouldn''t happen.'
    " TODO: Prompt user to select one and drop the rest.
  endif

  let stash_id = stashes[0][1]

  if !empty(stash_id)
    let output = s:gite('stash', 'apply', '-q', stash_id)
    if !v:shell_error
      call s:gite('stash', 'drop', '-q', stash_id)
    endif

    call s:git('rm', '-r', '--cached', '--quiet', '--ignore-unmatch', s:datadir)
    return v:shell_error == 0
  endif

  return 0
endfunction


" Check if it's safe to switch branches.
function! s:check_can_switch(to_branch) abort
  let win = winnr()
  for i in range(bufnr('$'))
    if !bufexists(i)
      continue
    endif

    let modified = getbufvar(i, '&modified')
    let buftype = getbufvar(i, '&buftype')

    if modified
      return 'There are unsaved buffers'
    endif

    if has('nvim') && buftype == 'terminal'
      return 'There are terminals open'
    endif
  endfor

  " Check if there's already a stash.
  let stash_key = s:stash_key()
  let stashes = s:find_stash(stash_key)

  if !empty(stashes)
    redraw
    echo 'There are multiple stashes matching: '.stash_key.'. '
          \.'They must be deleted to continue.'
    for info in stashes
      echo printf(' - %s %s: On branch %s', info[0], info[1], info[2])
    endfor

    let response = input('Delete listed stashes? [y/N] ')
    echo ''
    if response =~# 'y'
      let hashes = map(copy(stashes), 'v:val[0]')
      if !s:drop_stashes(hashes)
        return 'Could not drop stashes.'
      endif
      return 'Stashes deleted.  Try to switch branches again.'
    else
      return 'Existing stashes.'
    endif
  endif

  " Check if there's more than one target stash.
  let stash_key = s:stash_key(a:to_branch)
  let stashes = s:find_stash(stash_key)

  if len(stashes) > 1
    redraw
    echo 'There are more than one target stash matching: '.stash_key.'. '
          \.'There must only be one to continue.'
    for info in stashes
      echo printf(' - %s %s: On branch %s', info[0], info[1], info[2])
    endfor

    let response = input('Use the first one and delete the rest? [y/N] ')
    echo ''
    if response =~# 'y'
      let hashes = map(copy(stashes[1:]), 'v:val[0]')
      if !s:drop_stashes(hashes)
        return 'Could not drop stashes.'
      endif
      return 'Extrenuous target stashes deleted.  Try to switch branches again.'
    else
      return 'Too many target stashes.'
    endif
  endif

  return ''
endfunction


" List of branches (used for command completion).
function! gitbusy#branchlist(...) abort
  let output = s:git('branch', '-a')
  if v:shell_error
    return ''
  endif

  let branches = map(filter(split(output, "\n"), 'v:val[0] != "*"'), 's:strip(v:val)')
  return join(branches, "\n")
endfunction


" Rename all undo files that match an old base path.
" This expects the bases to be as described in `undofile()` with % replacing
" slashes.
function! s:fix_undo(undopath, oldbase, undobase) abort
  for file in glob(a:undopath.'/*', 1, 1)
    let newfile = substitute(file, a:oldbase, a:undobase, '')
    if newfile != file
      call rename(file, newfile)
    endif
  endfor
endfunction


" Bootstrap your session.
function! gitbusy#setup() abort
  if exists('s:_did_setup') || exists('SessionLoad') || !s:is_git_repo()
    return
  endif

  call s:check_exclusions()

  let data_dir = s:repo(s:datadir)
  if !isdirectory(data_dir)
    call mkdir(data_dir, 'p', 0700)
  endif

  let undo_dir = s:repo(s:undodir)
  if !isdirectory(undo_dir)
    call mkdir(undo_dir, 'p', 0700)
  endif

  let undopath = s:repo(s:undodir)
  let undobase = split(undofile(s:repo()), s:sep_p)[-1]

  let undo_base_file = s:repo(s:undodir.'/base')
  if filereadable(undo_base_file)
    let root = s:strip(join(readfile(undo_base_file), "\n"))
    if root != undobase
      " Need to fix the undo file names
      call s:fix_undo(undopath, root, undobase)
    endif
  endif

  " Store the base prefix of undo files to examine on the next setup.
  call writefile([undobase], undo_base_file)

  " Prefix the managed undodir so that old undos are still usable.
  let &undodir = undopath.','.s:orig_undodir

  let s:_did_setup = 1
endfunction


function! gitbusy#choose() abort
  let branches = split(gitbusy#branchlist(), "\n")
  let l = strlen(len(branches))

  redraw

  for i in range(len(branches))
    echo printf('%*d. %s', l, i + 1, branches[i])
  endfor

  let selection = input('Select a branch: ')
  echo ''

  if empty(selection)
    return
  endif

  let i = str2nr(selection) - 1
  if i >= 0 && i < len(branches) && !empty(branches[i])
    call gitbusy#switch(branches[i])
  endif
endfunction


" Switch to a branch.
function! gitbusy#switch(...) abort
  if !a:0 || empty(a:1)
    return gitbusy#choose()
  endif

  let branch = a:1
  let msg = s:check_can_switch(branch)
  if !empty(msg)
    echohl ErrorMsg
    echomsg 'Did''t switch branches:' msg
    echohl None
    return
  endif

  let key = s:stash_key()
  call s:save_session()
  silent bufdo bd
  call s:save_staged_hunks()
  call s:stash(key)

  unlet! s:_did_setup
  call s:git('checkout', branch)
  let key = s:stash_key()
  if s:unstash(key)
    call s:restore_staged_hunks()
    call s:load_session()
  endif

  call gitbusy#setup()
  unlet! s:_repo
  unlet! s:_gitroot
endfunction
