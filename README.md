# gitbusy.vim

Stash your Vim session using `git stash` before switching to another branch.


## Summary

A snapshot of your session (including staged hunks, undo history, and
`viminfo`/`shada`) is completely stashed in the git repository.  It allows you
to switch between branches mid-work without losing where you left off.

This plugin is heavily inspired by [vim-promiscuous][1].  A new plugin was
started because incorporating the changes I wanted would most likely lead to a
complete rewrite of `vim-promiscuous`.


## Installation

Any plugin manager will work.


## Usage

```vim
:GitBusy <branch name>
```

Use `:GitBusy` to switch to a branch.  If called with no arguments, a list of
branches will be printed for you to select from.  There is an option to enable
a shorter `:GB` command.

Options are documented in [`:help gitbusy`](doc/gitbusy.txt)


## Difference with vim-promiscuous

- Doesn't require [FZF][2] (although it is a pretty great addon for Neovim).
- `undodir` is not completely overridden.  A new path is added to it allowing
  your existing undo history to work.  Undo history created from that point
  forward will simply write to the managed directory.
- Your settings are used as-is (with the exception of `undodir`).  Settings are
  temporarily changed only to create the session.
- The stashed session is not persistent.  It's deleted as soon as a stash is
  restored.
- Undo history is stored within the git repository itself and is stashed along
  with your uncommitted work.  This allows you to rename the repository
  directory or move it without losing undo history.
- The `viminfo` or `shada` file is saved in the stash so marks, jumps,
  registers, etc. can be preserved.  This simply uses what you've configured
  `viminfo`/`shada` to persist.
- Staged commits are stored as a diff file in the stash.  I feel this is a
  safer way to save/restore uncommitted changes compared to using `git reset`.
  If all else fails, you can work the diff out yourself.


## Caveats / Notes

I consider these to be acceptable caveats.  But, `gitbusy` might not be right
for you if you don't like them.

- Manually using `git checkout` may leave dangling stashes.  You'll be prompted
  to delete them before `:GitBusy` will switch branches.
- All buffers must be saved (`nomodified`) in order to switch branches.
- Terminals can't be opened in [Neovim][3] in order to switch branches.
- Stashes may become large over time depending on your `viminfo`/`shada`
  options, undo levels, etc.
- You may lose work if you manually/accidentally remove `gitbusy`'s stashes.
  See [git-stash][4] about a possible recovery.
- `gitbusy`'s data directory is created at the work tree's root.
- An entry for `gitbusy`'s data directory is ignored by adding an entry to
  `.git/info/exclude`.
- Sessions are saved with the following settings: `buffers`, `curdir`, `folds`,
  `help`, `slash`, `tabpages`, `unix`
- Things may get mixed up if the current directory is different from what
  `gitbusy` thinks it should be.


## License

MIT


[1]: https://github.com/shuber/vim-promiscuous
[2]: https://github.com/junegunn/fzf
[3]: https://github.com/neovim/neovim
[4]: https://git-scm.com/docs/git-stash
