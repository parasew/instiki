**This bug is now solved**

Previously, a bug would not let you use `code` inside links text.

So this:
	Use the [`syntax`][syntax]
produces:
> Use the [`syntax`][syntax]

And this:
	Use the `[syntax][syntax]`
produces:
> Use the `[syntax][syntax]`

[syntax]: http://gogole.com

