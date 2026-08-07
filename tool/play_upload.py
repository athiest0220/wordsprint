#!/usr/bin/env python3
"""Upload an AAB to Google Play and roll it out to one or more tracks.

Uses a service-account JSON key + the Google Play Android Developer API, so the
whole publish is terminal-driven — no browser, no dragging.

Examples:
  python tool/play_upload.py                       # internal track, default AAB
  python tool/play_upload.py --track internal,alpha
  python tool/play_upload.py --aab path\\to.aab --notes "What's new"

Defaults assume this repo layout and the key at
  C:\\Users\\timga\\Desktop\\Word Sprint Keys\\play-publisher-key.json
"""
import argparse
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

DEFAULT_KEY = r"C:\Users\timga\Desktop\Word Sprint Keys\play-publisher-key.json"
DEFAULT_PKG = "com.wordsprint.wordsprint"
DEFAULT_AAB = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "build", "app", "outputs", "bundle", "release", "app-release.aab",
)
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def main() -> int:
    ap = argparse.ArgumentParser(description="Upload an AAB to Google Play.")
    ap.add_argument("--aab", default=DEFAULT_AAB, help="Path to the .aab")
    ap.add_argument("--key", default=DEFAULT_KEY, help="Service-account JSON key")
    ap.add_argument("--package", default=DEFAULT_PKG, help="applicationId")
    ap.add_argument("--track", default="internal",
                    help="Comma-separated tracks (internal,alpha,beta,production)")
    ap.add_argument("--status", default="completed",
                    help="Release status: completed|draft|inProgress|halted")
    ap.add_argument("--notes", default="", help="Release notes (en-US)")
    ap.add_argument("--version-code", type=int, default=0,
                    help="Assign this EXISTING versionCode to the track(s) "
                         "instead of uploading the AAB (no re-upload).")
    args = ap.parse_args()

    if not args.version_code and not os.path.isfile(args.aab):
        print(f"ERROR: AAB not found: {args.aab}", file=sys.stderr)
        return 2
    if not os.path.isfile(args.key):
        print(f"ERROR: key not found: {args.key}", file=sys.stderr)
        return 2

    tracks = [t.strip() for t in args.track.split(",") if t.strip()]
    print(f"AAB     : {args.aab}")
    print(f"Package : {args.package}")
    print(f"Tracks  : {', '.join(tracks)}  (status={args.status})")

    creds = service_account.Credentials.from_service_account_file(
        args.key, scopes=[SCOPE])
    svc = build("androidpublisher", "v3", credentials=creds,
                cache_discovery=False)
    edits = svc.edits()

    edit = edits.insert(body={}, packageName=args.package).execute()
    edit_id = edit["id"]
    print(f"Edit    : {edit_id}")

    if args.version_code:
        version_code = args.version_code
        print(f"Reusing existing versionCode {version_code} (no upload)")
    else:
        media = MediaFileUpload(args.aab, mimetype="application/octet-stream",
                                resumable=True)
        print("Uploading bundle (this is the 74MB push)...")
        bundle = edits.bundles().upload(
            packageName=args.package, editId=edit_id,
            media_body=media).execute()
        version_code = bundle["versionCode"]
        print(f"Uploaded: versionCode {version_code}")

    release = {"versionCodes": [version_code], "status": args.status}
    if args.notes:
        release["releaseNotes"] = [{"language": "en-US", "text": args.notes}]

    for track in tracks:
        edits.tracks().update(
            packageName=args.package, editId=edit_id, track=track,
            body={"track": track, "releases": [release]}).execute()
        print(f"Assigned versionCode {version_code} -> track '{track}'")

    edits.commit(packageName=args.package, editId=edit_id).execute()
    print("COMMITTED. Rollout is live to the selected track(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
