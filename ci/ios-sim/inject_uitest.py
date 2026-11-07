#!/usr/bin/env python3
"""Add a UI-test target to a temporary copy of ios/project.yml.

The committed ios/project.yml is restored by the caller. This does not change
the shipped 1.0 (2) app sources.
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "ios" / "project.yml"
text = SPEC.read_text()
anchor = """    archive:
      config: Release
targets:
"""
insert = """    archive:
      config: Release
    test:
      config: Debug
      targets:
        - FukuraScreenshots
targets:
"""
if anchor not in text:
    sys.exit("ios/project.yml scheme anchor not found; refusing to edit an unexpected file")
if "FukuraScreenshots" in text:
    sys.exit(0)
text = text.replace(anchor, insert, 1)
text += """
  FukuraScreenshots:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: ../ci/ios-sim/FukuraUITests
    dependencies:
      - target: Fukura
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kaiasai.fukura.screenshots
        GENERATE_INFOPLIST_FILE: YES
        TEST_TARGET_NAME: Fukura
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGNING_REQUIRED: NO
        CODE_SIGNING_ALLOWED: YES
"""
SPEC.write_text(text)
print("injected FukuraScreenshots into the working ios/project.yml")
