import argparse
import json
import sys
import subprocess
from . import runner
from .storage import read


def main():
    parser = argparse.ArgumentParser(description="Resumable Blender art gauntlet; artistic decisions arrive through evidence files.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("doctor")
    for name in ("init", "run"):
        p = sub.add_parser(name)
        p.add_argument("manifest")
        if name == "run":
            p.add_argument("--until", choices=["game-ready"], default="game-ready")
    for name in ("status", "resume", "report", "package"):
        sub.add_parser(name).add_argument("run")
    p = sub.add_parser("iterate")
    p.add_argument("run")
    p.add_argument("--plan", required=True)
    p = sub.add_parser("review")
    p.add_argument("run")
    p.add_argument("--from", dest="review_file", required=True)
    for name in ("packet", "export", "engine"):
        p = sub.add_parser(name)
        p.add_argument("run")
        p.add_argument("--candidate")
        if name == "packet":
            p.add_argument("--kind", choices=["source", "export"], default="source")
    args = parser.parse_args()
    try:
        if args.command == "doctor":
            import PIL
            result = {"python": sys.version.split()[0], "pillow": PIL.__version__, "blender": runner.executable("blender"), "godot": runner.executable("godot")}
        elif args.command in {"init", "run"}:
            path = runner.initialize(args.manifest)
            result = runner.status(path)
            if args.command == "run":
                result["driver"] = "assistant_session"
                result["request"] = "Supply baseline plan, execute iterate, dispatch blind packet, ingest review, repeat within budget. Resume this run across sessions."
        elif args.command == "iterate":
            result = runner.iterate(args.run, read(args.plan))
        elif args.command == "review":
            result = runner.ingest(args.run, args.review_file)
        elif args.command == "packet":
            result = runner.packet(args.run, args.candidate, args.kind)
        elif args.command == "export":
            result = runner.export_candidate(args.run, args.candidate)
        elif args.command == "engine":
            from .engine import capture
            result = capture(args.run, args.candidate)
        else:
            result = getattr(runner, args.command)(args.run)
        print(json.dumps(result, indent=2))
    except (ValueError, RuntimeError, OSError, KeyError, subprocess.SubprocessError) as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
