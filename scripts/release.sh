#!/bin/bash
set -e

TOTAL_STEPS=8
STEP=0
step() {
  STEP=$((STEP + 1))
  echo
  echo "[$STEP/$TOTAL_STEPS] $1"
}

step "Installing dependencies"
flutter pub get

step "Running tests"
flutter test

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

step "Verifying README installation snippet matches pubspec version"

README_OVERTURE_VERSION=$(grep -E '^\s*overture: \^' README.md | head -n1 | sed -E 's/.*\^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
if [ -z "$README_OVERTURE_VERSION" ]; then
  echo
  echo "❌ Aborting release: could not find 'overture: ^X.Y.Z' in README.md."
  echo "   The Install section must pin the current pubspec.yaml version."
  exit 1
fi
if [ "$README_OVERTURE_VERSION" != "$VERSION" ]; then
  echo
  echo "❌ Aborting release: README pins overture ^${README_OVERTURE_VERSION}, but pubspec.yaml is ${VERSION}."
  echo "   Update the README '## Install' block to '^${VERSION}' before releasing."
  exit 1
fi

echo "README pinned at overture ^${README_OVERTURE_VERSION} ✓"

step "Validating package (dry-run)"
flutter pub publish --dry-run

step "Running pana (pub.dev score)"
PANA_OUT=$(pana --no-warning . | tee /dev/stderr)
if ! grep -q "Points: 160/160" <<<"$PANA_OUT"; then
  echo
  echo "❌ Aborting release: pana score is below 160/160. Fix the issues above."
  exit 1
fi

step "Creating tag v$VERSION"
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists, skipping"
else
  git tag "v$VERSION"
fi

step "Pushing"
git push origin master
git push --tags

step "Publishing to pub.dev"
flutter pub publish --force

echo
echo "🎉 Done! Published v$VERSION"
