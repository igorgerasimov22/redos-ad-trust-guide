#!/usr/bin/env bash
set -u

AD_DOMAIN="${AD_DOMAIN:-ad.example.local}"
AD_DC="${AD_DC:-dc01.ad.example.local}"

section() {
  printf '\n===== %s =====\n' "$1"
}

section "HOST"
hostname -f || true

section "IPA STATUS"
ipactl status || true

section "VERSIONS"
rpm -q ipa-server ipa-server-trust-ad samba samba-dcerpc samba-winbind python3-samba || true

section "SAMBA MIT KERBEROS"
if smbd -b 2>/dev/null | grep -q HAVE_KADM5SRV_MIT; then
  echo "OK: HAVE_KADM5SRV_MIT"
else
  echo "ERROR: HAVE_KADM5SRV_MIT not found"
fi

section "DNS A/AAAA"
getent hosts "$AD_DC" || true

section "DNS SRV"
dig +short "_ldap._tcp.${AD_DOMAIN}" SRV || true
dig +short "_kerberos._tcp.${AD_DOMAIN}" SRV || true

section "TIME"
date -Ins || true
timedatectl || true
chronyc tracking || true

section "AD PORTS"
for port in 53 88 135 389 445 464 3268; do
  printf '%-6s ' "$port"
  nc -zvw3 "$AD_DC" "$port" 2>&1 || true
done

section "LOCAL SAMBA/RPC"
ss -lntp | grep -E ':(135|445)\b' || true
ps -ef | grep -E 'smbd|winbindd|samba-dcerpcd|rpcd_' | grep -v grep || true

section "KERBEROS CACHE"
klist || true

printf '\nPrecheck finished.\n'
