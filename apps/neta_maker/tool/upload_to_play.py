#!/usr/bin/env python3
"""Upload a release AAB to a Google Play testing track via the Android Publisher API.

Usage:
    python3 tool/upload_to_play.py <package_name> <aab_path> [track]

Requires android/play-publisher-upload-key.json (service account key, gitignored).
"""
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
KEY_FILE = "android/play-publisher-upload-key.json"


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <package_name> <aab_path> [track]")
        sys.exit(1)

    package_name = sys.argv[1]
    aab_path = sys.argv[2]
    track = sys.argv[3] if len(sys.argv) > 3 else "internal"

    creds = service_account.Credentials.from_service_account_file(
        KEY_FILE, scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=creds)

    edit = service.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]
    print(f"edit id: {edit_id}")

    media = MediaFileUpload(aab_path, mimetype="application/octet-stream")
    bundle = (
        service.edits()
        .bundles()
        .upload(packageName=package_name, editId=edit_id, media_body=media)
        .execute()
    )
    version_code = bundle["versionCode"]
    print(f"uploaded bundle, versionCode: {version_code}")

    service.edits().tracks().update(
        packageName=package_name,
        editId=edit_id,
        track=track,
        body={
            "releases": [
                {
                    "versionCodes": [str(version_code)],
                    "status": "completed",
                }
            ]
        },
    ).execute()
    print(f"assigned versionCode {version_code} to track '{track}'")

    result = service.edits().commit(packageName=package_name, editId=edit_id).execute()
    print(f"committed edit: {result['id']}")


if __name__ == "__main__":
    main()
