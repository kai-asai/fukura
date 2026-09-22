"""Inject public updater settings before code signing. No private keys are read."""
import base64
import os
import plistlib
import re
import sys
from urllib.parse import urlsplit


def configuration(env):
    feed = env.get("SPARKLE_FEED_URL", "")
    key = env.get("SPARKLE_PUBLIC_KEY", "")
    if bool(feed) != bool(key):
        raise ValueError("SPARKLE_FEED_URL and SPARKLE_PUBLIC_KEY must be supplied together")
    result = {}
    if feed:
        url = urlsplit(feed)
        if url.scheme != "https" or not url.hostname or url.username or url.password:
            raise ValueError("SPARKLE_FEED_URL must be an HTTPS URL without credentials")
        if len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError("SPARKLE_PUBLIC_KEY must be a base64-encoded 32-byte Ed25519 key")
        result.update(SUFeedURL=feed, SUPublicEDKey=key)
    for env_key, plist_key in [
        ("APP_VERSION", "CFBundleShortVersionString"), ("APP_BUILD", "CFBundleVersion")
    ]:
        if env.get(env_key):
            if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", env[env_key]):
                raise ValueError(f"{env_key} must be a numeric version")
            result[plist_key] = env[env_key]
    identity = env.get("CODESIGN_IDENTITY", "")
    if env.get("NOTARY_PROFILE") and not identity.startswith("Developer ID Application:"):
        raise ValueError("Notarization requires a Developer ID Application identity")
    if env.get("PUBLIC_RELEASE") == "1":
        if not (feed and key and env.get("NOTARY_PROFILE")
                and identity.startswith("Developer ID Application:")
                and env.get("APP_VERSION") and env.get("APP_BUILD")):
            raise ValueError("PUBLIC_RELEASE requires updater configuration, Developer ID, notarization, APP_VERSION and APP_BUILD")
    return result


if __name__ == "__main__":
    try:
        values = configuration(os.environ)
        if len(sys.argv) != 2:
            raise ValueError("Usage: configure-updates.py --validate | Info.plist")
        if sys.argv[1] != "--validate":
            with open(sys.argv[1], "rb") as source:
                info = plistlib.load(source)
            for name in ("SUFeedURL", "SUPublicEDKey"):
                info.pop(name, None)
            info.update(values)
            with open(sys.argv[1], "wb") as destination:
                plistlib.dump(info, destination)
    except (ValueError, OSError) as error:
        sys.exit(str(error))
