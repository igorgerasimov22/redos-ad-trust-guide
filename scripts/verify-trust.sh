#!/usr/bin/env bash
set -u

AD_DOMAIN="${AD_DOMAIN:-ad.example.local}"
AD_USER="${AD_USER:-user}"

section() {
  printf '\n===== %s =====\n' "$1"
}

section "IPA STATUS"
ipactl status || true

section "TRUST"
ipa trust-show "$AD_DOMAIN" || true

section "TRUST DOMAINS"
ipa trustdomain-find "$AD_DOMAIN" || true

section "IDENTITY"
id "${AD_USER}@${AD_DOMAIN}" || true
getent passwd "${AD_USER}@${AD_DOMAIN}" || true

section "SAMBA BUILD"
rpm -q samba samba-dcerpc samba-winbind python3-samba || true
smbd -b | grep HAVE_KADM5SRV_MIT || true
