# Официальные источники

## РЕД ОС

**Создание доверительных отношений IPA и MSAD**  
https://redos.red-soft.ru/base/redos-8_0/8_0-administation/8_0-domain-redos/8_0-installation-ipa/8_0-ipa-trust-ad/

Ключевые пункты:

- РЕД ОС 8;
- `ipa-server-trust-ad`;
- `ipa-adtrust-install`;
- Samba с поддержкой MIT Kerberos;
- суффикс `m` в версии RPM;
- `smbd -b | grep HAVE_KADM5SRV_MIT`;
- `dnf dg samba`;
- исключение Samba из обычных обновлений;
- создание `ipa trust-add ... --two-way=true`;
- `ipa trust-fetch-domains`.

## FreeIPA

**Active Directory trust setup**  
https://www.freeipa.org/page/Active_Directory_trust_setup.html

Использовалось для общей архитектуры trust, DNS, Kerberos, `ipa-adtrust-install`, firewall и требований к AD administrator.

## Microsoft

**Настройка брандмауэра для управления доменом AD и отношениями доверия**  
https://learn.microsoft.com/ru-ru/troubleshoot/windows-server/active-directory/config-firewall-for-ad-domains-and-trusts

Использовалось для актуальных портов Windows Server, включая RPC Endpoint Mapper и dynamic RPC range.

## FreeIPA upstream: Samba 4.23

**dcerpc: Support Samba 4.23**  
https://github.com/freeipa/freeipa/commit/ae8e850708b118b3da9c9ebc2d5cf8b085d845df

**dcerpc: make sure forest trust info structure version is 1**  
https://github.com/freeipa/freeipa/commit/96c3d2d1ad6c947678a15928de258f462c3ea4ed

Эти коммиты полезны для понимания изменений Samba 4.23, но не являются рекомендацией вручную патчить production FreeIPA.
