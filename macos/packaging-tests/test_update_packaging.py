import base64
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "configure_updates", Path(__file__).parents[1] / "configure-updates.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class UpdatePackagingTests(unittest.TestCase):
    def test_unconfigured_build_has_no_feed(self):
        self.assertEqual(module.configuration({}), {})

    def test_valid_public_configuration(self):
        env = {
            "SPARKLE_FEED_URL": "https://example.com/appcast.xml",
            "SPARKLE_PUBLIC_KEY": base64.b64encode(bytes(32)).decode(),
            "CODESIGN_IDENTITY": "Developer ID Application: Example (TEAM)",
            "NOTARY_PROFILE": "local-keychain-profile",
            "PUBLIC_RELEASE": "1", "APP_VERSION": "1.1.0", "APP_BUILD": "3",
        }
        self.assertEqual(module.configuration(env)["CFBundleVersion"], "3")

    def test_rejects_partial_or_unsafe_configuration(self):
        key = base64.b64encode(bytes(32)).decode()
        for env in [
            {"SPARKLE_PUBLIC_KEY": key},
            {"SPARKLE_FEED_URL": "https://example.com/feed"},
            {"SPARKLE_FEED_URL": "http://example.com/feed", "SPARKLE_PUBLIC_KEY": key},
            {"SPARKLE_FEED_URL": "https://user:secret@example.com/feed", "SPARKLE_PUBLIC_KEY": key},
            {"SPARKLE_FEED_URL": "https://example.com/feed", "SPARKLE_PUBLIC_KEY": "invalid"},
            {"NOTARY_PROFILE": "profile"}, {"PUBLIC_RELEASE": "1"},
            {"APP_BUILD": "not-a-version"},
        ]:
            with self.subTest(env_keys=list(env)):
                with self.assertRaises(ValueError):
                    module.configuration(env)


if __name__ == "__main__":
    unittest.main()
