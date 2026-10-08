#!/bin/bash
# setup-signing.sh - give local builds one code identity that never changes.
#
# macOS ties every privacy grant (Accessibility, Contacts, Calendar, Reminders,
# Automation) to the app's code identity. An ad-hoc signature is a fresh
# identity on every build, so each rebuild used to cost a full round of
# permission prompts. Signing with a fixed self-signed certificate keeps the
# identity stable, and the grants survive rebuilds.
#
# The certificate lives in its own keychain (not the login keychain) with a
# throwaway password, so `make app` can unlock it without prompting. It is only
# good for signing this app on this Mac: it is not trusted by anyone else and
# never leaves the machine. Safe to re-run; it does nothing once set up.

set -eu

IDENTITY="Sidekick Local Signing"
KEYCHAIN="$HOME/Library/Keychains/sidekick-signing.keychain-db"
KC_PASS="sidekick-local"

# codesign only looks in keychains on the user search list.
add_to_search_list() {
  local current
  current=$(security list-keychains -d user | sed 's/^ *"//; s/"$//')
  if ! printf '%s\n' "$current" | grep -qxF "$KEYCHAIN"; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s $current "$KEYCHAIN"
  fi
}

if [ -f "$KEYCHAIN" ] && security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
  add_to_search_list
  echo "setup-signing: already set up ($KEYCHAIN)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Apple's LibreSSL writes a PKCS#12 that `security import` reads; a Homebrew
# OpenSSL 3 would need -legacy for the same thing.
OPENSSL=/usr/bin/openssl

cat >"$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 7300 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
"$OPENSSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$IDENTITY" -passout pass:"$KC_PASS" -out "$TMP/identity.p12"

rm -f "$KEYCHAIN"
security create-keychain -p "$KC_PASS" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"   # no auto-lock timeout
security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$KC_PASS" -T /usr/bin/codesign >/dev/null
# Without this, the first codesign shows a "wants to use your keychain" dialog.
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PASS" "$KEYCHAIN" >/dev/null
add_to_search_list

echo "setup-signing: created \"$IDENTITY\" in $KEYCHAIN"
echo "setup-signing: the next 'make app' asks for permissions one last time; after that they stick."
