<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

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
