"""The repo's `env` file (KEY=value lines, see its header) for the tools, and the docs' shorthand folder names.

    from env import ENV, path
    path("textures-src/lab/x.png")   -> TEXTURES_SRC/lab/x.png; any other relative path is under the repo root

`python3 tools/env.py` is its self-check.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# split at the first '=' and strip nothing but a CR: the Yandex paths hold a space
ENV = {k: v for k, _, v in (l.partition("=") for l in (ROOT / "env").read_text().splitlines() if "=" in l and not l.startswith("#"))}
# the shorthand folder names the docs, manifests and tool usage lines use for the out-of-repo folders: (env key, subdir)
NAMES = {
    "parasite": ("BUILD", ""),
    "app": ("BUILD", "resources/app"),
    "textures-src": ("TEXTURES_SRC", ""),
    "models-src": ("MODELS_SRC", ""),
    "sounds-src": ("SOUNDS_SRC", ""),
    "ai-src": ("AI_SRC", ""),
}


def path(p):
    """a repo-relative path, a leading shorthand folder name resolved to its env dir; an absolute path is kept."""
    head, _, rest = str(p).partition("/")
    if head in NAMES:
        key, sub = NAMES[head]
        return Path(ENV[key]) / sub / rest
    return ROOT / p


def resolve_args(args):
    """command-line args with a leading shorthand folder (`app/models/x.glb`) resolved to its env dir; the rest kept."""
    return [str(path(a)) if "/" in a and a.partition("/")[0] in NAMES else a for a in args]


if __name__ == "__main__":
    assert resolve_args(["-o", "app/x.glb", "a/b", "3"]) == ["-o", str(Path(ENV["BUILD"]) / "resources/app/x.glb"), "a/b", "3"]
    assert path("textures-src/lab/a.png") == Path(ENV["TEXTURES_SRC"]) / "lab/a.png"
    assert path("app/models") == Path(ENV["BUILD"]) / "resources/app/models"
    assert path("app") == Path(ENV["BUILD"]) / "resources/app"
    assert path("art/sounds.json") == ROOT / "art/sounds.json"
    assert path("/tmp/a") == Path("/tmp/a")
    assert path("apps/x") == ROOT / "apps/x"
    assert all(Path(path(n)).is_dir() for n in NAMES), {n: str(path(n)) for n in NAMES}
    print("ok", ENV)
