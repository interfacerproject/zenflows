# Style Guide

Having a style guide is great for having consistency.


## Elixir

For Elixir (`.ex`) or Elixir script files (`.exs`), follow these guide lines:

* Keep line lengths at about 80 lines, not a hard rule.
* Use Unix line endings and make sure you have a <newline> character at the end
  of the file (any decent editor will already do that).
* Use tabs for indentation, spaces for aligment.
* Don't indent the top-level code in modules and avoid nesting modules.
* Use trailing commas in multi-line lists, maps, functions, etc. wherever
  possible.
* Prefer exclicit `do ... end` syntax over `, do: ...` syntax.


## Markdown

For Markdown files (`.md`), follow these guide lines:

* Keep lines lengths at most 80 lines (unless it is in a code block, then it is
  not a hard rule).
* Capitalize first letters of all the titles (except for words like and, or, of,
  etc.)
* Separate all titles from each other with two blank lines.
* Separate a title from the immediate paragraph by a blank line.
* Separate a list from the before and after paragraph by a blank line.
* Separate a code block (not inline) from the before and after paragraph by a
  blank line.
* Aling the lines breaked from a list line like this:

  ```
  * Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo

    1. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
      eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
      minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex

    2. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
      eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
      minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex

  * Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
  ```
