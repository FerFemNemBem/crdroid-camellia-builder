# Known-good states

One file per release tag of this repository (`v1.0.xml`, ...): the output of `repo manifest -r`
right after the sync of a build that I installed and tested on my phone. It pins every project
(crDroid, device tree, kernel, ViPER) to an exact commit.

Use it with `bash scripts/04-sync.sh --known-good <tag>`, see [docs/updates.md](../../docs/updates.md#known-good-states).
It is created from `source-state.xml` of the tested build.
