vim-reasonml:
=========================================

**Native Reason development with `esy` and Merlin**

<img width="374px" height="374px" src="./doc/vim-reasonml.png" />


`vim-reasonml` provides vim IDE features for **native** Reason projects that
use [esy](https://esy.sh) and `merlin`.

## Features:

- Automatically loads Merlin plugin from your esy `devDependencies`.
- Merlin autocomplete, goto-location, type-at-cursor features (provided by merlin)
- Airline integration for esy projects and compilation errors.
- `:ReasonPrettyPrint` with enhanced syntax error locations.
- Reason syntax highlighting and Dune build config syntax highlighting.
- Highlighting of esy `#{build variables}` in `.json` files.
- Preliminary Windows support with `esy` Windows.

See [The vim-reasonml Plugin Documentation](./doc/vim-reasonml.txt).

<img width="663px" height="536px" src="./doc/screenshot.png" />


## Install

- `npm install -g esy`
- Install `vim-reasonml` with your vim plugin manager. If using
  [`vim-plug`](https://github.com/junegunn/vim-plug) add `Plug 'jordwalke/vim-reasonml`
  to your `~/.vimrc`)
- Create a project with `@opam/merlin` as a `devDependency`. You can fork
  [hello-reason](https://github.com/esy-ocaml/hello-reason) to get started.
- `esy install && esy build` as you normally would.
- Open a `.re` file from the project in Vim.


## Formatting

The command `:ReasonPrettyPrint` invokes the binary `refmt` which must be
available on your `PATH`.  Add a keyboard mapping shortcut like this:

```vim
autocmd FileType reason map <buffer> <D-C> :ReasonPrettyPrint<Cr>
```

## Error/Warning Highlighting:
- To enable syntastic support, add the following to your `~/.vimrc`:

```
" If using vim-plug, install syntastic:
Plug 'scrooloose/syntastic'
```

- [Neomake](https://github.com/neomake/neomake) support can be enabled by setting
`let g:neomake_reason_enabled_makers = ['merlin']`.

## Merlin

Merlin is supported out of the box by pulling merlin from your
`devDependencies`. You will need to install an autocomplete plugin to get
natural complete-as-you-type behavior. For example to install
[`mucomplete`](https://github.com/lifepillar/vim-mucomplete), using `vim-plug`,
add the following config:

```vim
" If using vim-plug, install mucomplete:
Plug 'lifepillar/vim-mucomplete'
let g:mucomplete#can_complete = {}
let g:mucomplete#enable_auto_at_startup = 1
let g:mucomplete#chains = {'default': ['omni']}
```


## Airline Integration

`vim-reasonml` includes an airline extension which show the project name of the
current file (and project status) in an airline segment. Another included
extension shows the current number of syntastic errors and warnings.

```vim
" Airline: Enable the airline extensions for esy project status and reason
" syntastic plugin.
let g:airline_extensions = ['esy', 'reason']
let g:reasonml_project_airline=1
let g:reasonml_syntastic_airline=1
let g:reasonml_clean_project_airline=1
let g:airline#extensions#whitespace#enabled = 0
let g:airline_powerline_fonts = 1
let g:airline_skip_empty_sections = 1
```


## LICENSE

Some files from vim-reasonml are based on the Rust vim plugin and so we are including that license.
