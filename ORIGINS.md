Much of plugin/reason.vim was copied from Vim-Plug, which is under MIT Just
like vim-reason-loader is released under MIT.
https://github.com/junegunn/vim-plug/blob/master/plug.vim

Much of the Reason syntax highlighting was coppied from the vim-rust plugin
(see the comment header in after/syntax/reason.vim).

The `vendor/` directory vendors dependencies on
[vim-shell](https://github.com/xolox/vim-shell) and
[vim-misc](https://github.com/xolox/vim-misc) but vim-reason had to include
them because it's difficult to load them from a vendored directory.

It shouldn't cause any problems if you already depend on those same plugins elsewhere
