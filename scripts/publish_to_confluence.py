#!/usr/bin/env python3
"""
Publish the eEFKA HLD to a Confluence page via the REST API.

Supports both Confluence Cloud and Data Center / Server.
Creates the page if it does not exist; updates it (bumping the version) if it does.

Usage
-----
  # Via environment variables (recommended):
  export CONFLUENCE_URL=https://your-org.atlassian.net
  export CONFLUENCE_USER=you@example.com
  export CONFLUENCE_TOKEN=<your-api-token>
  export CONFLUENCE_SPACE=ARCH
  export CONFLUENCE_PARENT_ID=123456   # optional
  python scripts/publish_to_confluence.py

  # Via CLI flags:
  python scripts/publish_to_confluence.py \\
    --url  https://your-org.atlassian.net \\
    --user you@example.com \\
    --token <api-token> \\
    --space ARCH \\
    --parent-id 123456

API Token (Confluence Cloud)
----------------------------
  Generate at: https://id.atlassian.com/manage-profile/security/api-tokens

Personal Access Token (Data Center / Server)
--------------------------------------------
  Generate at: {your-confluence-url}/plugins/servlet/de.resolution.apitokenauth
  Pass it as --token; set --user to your username.
"""

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("requests is not installed — run: pip install requests")


BODY_FILE = Path(__file__).parent.parent / "confluence" / "HLD-eEFKA-page-body.html"
DEFAULT_TITLE = "eEFKA Database Synchronisation — High-Level Design"


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Publish eEFKA HLD to Confluence",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--url",       default=os.getenv("CONFLUENCE_URL"),   help="Confluence base URL (no trailing slash)")
    p.add_argument("--user",      default=os.getenv("CONFLUENCE_USER"),  help="Username or email address")
    p.add_argument("--token",     default=os.getenv("CONFLUENCE_TOKEN"), help="API token or Personal Access Token")
    p.add_argument("--space",     default=os.getenv("CONFLUENCE_SPACE", "ARCH"), help="Confluence space key (default: ARCH)")
    p.add_argument("--parent-id", default=os.getenv("CONFLUENCE_PARENT_ID"),    help="Parent page ID (optional)")
    p.add_argument("--title",     default=DEFAULT_TITLE,                          help="Page title")
    p.add_argument("--body-file", default=str(BODY_FILE),                         help="Path to Confluence storage format HTML")
    p.add_argument("--dry-run",   action="store_true",                            help="Print the payload without publishing")
    return p


def get_session(user: str, token: str) -> requests.Session:
    s = requests.Session()
    s.auth = (user, token)
    s.headers.update({"Content-Type": "application/json", "Accept": "application/json"})
    return s


def find_existing_page(session: requests.Session, api: str, space: str, title: str) -> dict | None:
    url = f"{api}/content"
    params = {"title": title, "spaceKey": space, "expand": "version,ancestors"}
    resp = session.get(url, params=params)
    resp.raise_for_status()
    results = resp.json().get("results", [])
    return results[0] if results else None


def create_page(session: requests.Session, api: str, space: str, title: str, body: str, parent_id: str | None) -> dict:
    payload: dict = {
        "type": "page",
        "title": title,
        "space": {"key": space},
        "body": {"storage": {"value": body, "representation": "storage"}},
    }
    if parent_id:
        payload["ancestors"] = [{"id": parent_id}]
    resp = session.post(f"{api}/content", json=payload)
    resp.raise_for_status()
    return resp.json()


def update_page(session: requests.Session, api: str, page_id: str, title: str, body: str, current_version: int) -> dict:
    payload = {
        "version": {"number": current_version + 1},
        "title": title,
        "type": "page",
        "body": {"storage": {"value": body, "representation": "storage"}},
    }
    resp = session.put(f"{api}/content/{page_id}", json=payload)
    resp.raise_for_status()
    return resp.json()


def page_url(base_url: str, page: dict) -> str:
    webui = page.get("_links", {}).get("webui", "")
    return f"{base_url}/wiki{webui}" if webui else f"{base_url} (page ID: {page['id']})"


def main() -> int:
    args = build_parser().parse_args()

    missing = [name for name, val in [("--url", args.url), ("--user", args.user), ("--token", args.token)] if not val]
    if missing:
        print(f"ERROR: required arguments missing: {', '.join(missing)}")
        print("Set them via CLI flags or environment variables (CONFLUENCE_URL, CONFLUENCE_USER, CONFLUENCE_TOKEN).")
        return 1

    body_path = Path(args.body_file)
    if not body_path.exists():
        print(f"ERROR: body file not found: {body_path}")
        return 1

    body = body_path.read_text(encoding="utf-8")
    base_url = args.url.rstrip("/")
    api = f"{base_url}/wiki/rest/api"

    if args.dry_run:
        payload = {
            "type": "page",
            "title": args.title,
            "space": {"key": args.space},
            "body": {"storage": {"value": "(body omitted — see body file)", "representation": "storage"}},
        }
        print("=== DRY RUN — payload that would be sent ===")
        print(json.dumps(payload, indent=2))
        print(f"\nTarget: {api}/content")
        print(f"Body file: {body_path} ({len(body):,} chars)")
        return 0

    session = get_session(args.user, args.token)

    # verify connectivity
    try:
        ping = session.get(f"{api}/space/{args.space}")
        ping.raise_for_status()
    except requests.HTTPError as exc:
        print(f"ERROR: could not reach Confluence space '{args.space}': {exc}")
        if exc.response is not None and exc.response.status_code == 401:
            print("  → Check your --user and --token credentials.")
        elif exc.response is not None and exc.response.status_code == 404:
            print(f"  → Space key '{args.space}' not found. Check --space.")
        return 1

    existing = find_existing_page(session, api, args.space, args.title)

    if existing:
        page_id = existing["id"]
        version = existing["version"]["number"]
        print(f"=> Page exists (ID={page_id}, version={version}). Updating to version {version + 1}…")
        page = update_page(session, api, page_id, args.title, body, version)
        print(f"=> Updated successfully.")
    else:
        print(f"=> Creating new page '{args.title}' in space '{args.space}'…")
        page = create_page(session, api, args.space, args.title, body, args.parent_id)
        print(f"=> Created successfully (ID={page['id']}).")

    print(f"\n   {page_url(base_url, page)}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
