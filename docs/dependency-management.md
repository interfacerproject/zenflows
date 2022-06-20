# Dependency Management

The dependencies are put in version control in Zenflows.  But elixir/mix doesn't
like this approach because it puts generated files (such as erlex, absinthe) in
the dependencies' directory, which makes it hard to track/differentiate source
files and generated files.

For that reason, the actual dependencies (the real source code) are stored and
tracked in the `.deps/` directory instead of the `deps/` directory.  Then, the
`.deps/` directory is copied over to `deps/` directory when we want to use the
dependencies in the project.  Similarly, `deps/` is copied over to `.deps/`
whenever we update or add a dependency (of course, `deps/` is cleaned first, in
order to avoid generated files).

But this approach needs some care when you want to update or add a dependency:
you must first clean the `deps/` directory with `mann dep.clean`, then copy
`.deps/` over to `deps/` with `mann dep.setup`, then use whatever mix command
you want to add or update a dependency (to update, use `mann mix deps.update
mydep`), then copy `deps/` over back to `.deps/`.

Let's give some examples.  Suppose you want to update `absinthe`.  You do:

1. `mann dep.clean`
2. `mann dep.setup`
3. `mann mix deps.update absinthe`
4. `mann dep.copy`
5. `git add .deps/`
6. `git commit -m 'dep: update absinthe to x.y.z'`

Now let's suppose you want to add a new dependency, `absinthe`, to your project.
You do:

1. `mann dep.clean`
2. `mann dep.setup`
3. edit `mix.exs` to add the dependency
4. `mann dep.copy`
5. `git add .deps/`
6. `git commit -m 'dep: add absinthe x.y.z'`

Similar process happens with dependency removal, but I think it is clear now.
