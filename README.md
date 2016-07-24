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


## License

MIT


[1]: https://github.com/shuber/vim-promiscuous
[2]: https://github.com/junegunn/fzf
