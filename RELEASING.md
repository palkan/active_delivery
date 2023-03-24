# How to release a gem

This document describes a process of releasing a new version of a gem.

1. Bump version.

```sh
git commit -m "Bump 1.<x>.<y>"
```

We're (kinda) using semantic versioning:

- Bugfixes should be released as fast as possible as patch versions.
- New features could be combined and released as minor or patch version upgrades (depending on the _size of the feature_—it's up to maintainers to decide).
- Breaking API changes should be avoided in minor and patch releases.
- Breaking dependencies changes (e.g., dropping older Ruby support) could be released in minor versions.

How to bump a version:

- Change the version number in `lib/active_delivery/version.rb` file.
- Update the changelog (add new heading with the version name and date).
- Update the installation documentation if necessary (e.g., during minor and major updates).

2. Push code to GitHub and make sure CI passes.

```sh
git push
```

3. Release a gem.

```sh
make release
```

Under the hood we generated pre-transpiled files with Ruby Next and use [gem-release](https://github.com/svenfuchs/gem-release) to publish a gem. Then, a Git tag is created and pushed to the remote repo.
