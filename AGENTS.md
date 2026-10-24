# Hex Hollow repository workflow

The active Manus project uses its managed `origin` repository and Preview. The user's `airalcorn2/hex-hollow` GitHub `main` is a separate, self-contained distribution containing every game asset. Preserve both repositories and their histories; do not rebind the project or force-push.

Managed release saving stores media separately and can remove binary assets from its own Git index. Therefore **do not push a media-free managed release directly to GitHub `main`**. Do not remove managed asset-ignore rules or alter installed release helpers to circumvent that behavior.

After saving and verifying the normal managed release and pushing its exact SHA to managed `origin/main`, update GitHub through a separate clean checkout:

```bash
python3 tools/sync_portable_github.py --repo-dir /absolute/path/to/hex-hollow-portable --push
```

On first use, clone `https://github.com/airalcorn2/hex-hollow.git` into that separate directory. The sync command merges the saved source history, preserves GitHub-only asset tracking, copies current verified media from `assets.lock.json`, retains license notices and import sidecars, and refuses dirty checkouts or unexpected asset modifications. Git conflicts must be resolved explicitly; never reset, clean, or force-push to bypass them.

The portable checkout's trailing `!/assets/**` rule intentionally differs from the managed project's ignore rules. Keep it. Godot caches, exported builds, dependencies, and secrets stay out of source control. Run the existing native `tools/hollow_check.gd` suite against a fresh portable checkout after changing the distribution workflow. No Manus runtime, media downloads, or Node.js are needed just to open and play that checkout in Godot.
