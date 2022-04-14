# But Why?

Nixpkgs relies on patching low level tools and injecting extra configuration
into build systems. When it all works, Nix is invisible magic to the user. When
it fails, Nix's complexity explodes into full view. Understanding what went
wrong usually requires reading the Nixpkgs source code (something most users
should never be expected to do since neither bash nor nix are known for
readability).

Much of the complexity comes from working with software on the precarious ledge
of abstraction. As you try to use more and more "esoteric" software, you
approach the edge of what's maintained. Accidentally cross over into something
that doesn't fit the abstractions and you're on your own.

What if we could remove the ledge? Instead of modifying software to work in our
Nix environment, let's modify our Nix environment to work with our software.

# How it (hopefully) works

1. Inside a build, create a new user namespace and pivot root towards something
   that looks more traditional. All dependencies are copied (or symlinked) into
   the new root's /usr/* directories.

2. Software is built using the same commands you'd use on any other
   distribution because the fake root looks like a normal distro.

3. Move the /usr/bin folder to /raw. Create wrappers in /usr/bin for
   everything in /usr/raw. The wrappers will use a similar namespace/pivot root
   trick to create an FHS on the fly. The runtime FHS will be created by
   OverlayFS-ing the folders in /usr with whatever happens to already be there
   at runtime.
4. /usr is moved to $out.


Basically, run all software how Steam is run now, but use newer tools and make
it composable.

One concerning part is the OverlayFS. At first glance, it seems to break purity.
The software we build can now depend on libraries and files from the outside
world. Doesn't this defeat the point of using Nix?

I would argue that it doesn't. First, builds are still performed in a pure,
carefully controlled environment. No overlaying happens at build time. If you
forget to specify a dependency, the build will still fail. Software remains
reproducible. Regardless, the other benefits of Nix, like atomic upgrades, still
apply.

If dependencies have to be specified as they normally are in Nixpkgs, why is the
OverlayFS needed? Let's imagine you're doing some local development on Wesnoth
(a game which depends on sdl2). You're on Nixos so your path looks something
like this before entering your dev environment.

```
/nix/store/...
/bin/sh
/run/...
```

You enter the development environment for Wesnoth (which just mounts the FHS and
pivots root) to look something like this.

```
/nix/store/...
/bin/ -> /usr/bin/
/usr/bin/{sh,gcc,...}
/usr/lib/{libsdl2.so,libc.so,...}
```

Great! You now have access to all the libraries for Wesnoth and gcc. If you
tried to compile the project though, gcc wouldn't see any of Wesnoth's
dependencies. Gcc is also a wrapper. Gcc's wrapper, without the OverlayFS, would
"overwrite" /usr/lib with the version it had at build time. Since gcc doesn't
depend on sdl2, that library has disappeared. Using an OverlayFS fixes that
problem. Gcc's wrapper will take the existing /usr/lib and overlay its own
dependencies on top. This works regardless of how deeply nested your shell outs
are.

What if I'm not on Nixos and already have a busy /usr/ directory? The wrapper
could watch for an "IN_NIX_FHS" environment variable or file. If that isn't set,
it doesn't do the overlay and sets the variable. Nix software remains pure from
your actual environment.

Does this have performance implications? Probably. The OverlayFS is in the
kernel and hopefully well optimized. The wrapper overhead (mounting and
pivoting) only happen when you execute a binary. How often does software shell
out in a performance critical way? You could probably design some pathological
cases, but I'm not sure those come up in "real" software. Replacing the Bash
wrapper with C might help if it's a problem.

What if I want to mix library versions? You should be fine! Because each program
mounts its own version of the FHS on top of the others, it should always see the
versions it expects without breaking anyone else. If your library dependencies
form a diamond and expect incompatible versions though, things won't work.

What are the benefits? Creating packages is massively simplified because no
patching or hidden flags happen in the background. The wrapping is
language/ecosystem agnostic and easy to bypass. Development just works without
needing to patch tools. Explaining how to accomplish something in Nix fits
closer with someone's existing Linux intuitions.

# What's that spaghetti?

In the gccWrapped.nix file, you can see an example package using these tricks in
an adhoc/hacky way. The goal would be to generalize all of the
mounting/wrapping/namespace stuff into a function so users just provide a list
of dependencies and the commands they would run on a normal distro. You can
follow the imports to see how it all works. gcc.nix compiles gcc, gccWrapped
wraps the executables, and wrapper.nix defines the wrapper script.

# TODOs

* Benchmark the wrappers
* Fully bootstrap off Nixpkgs
* Create abstractions for the mounting stuff
* Figure out how aggressive to be with wrapping
* Package things
