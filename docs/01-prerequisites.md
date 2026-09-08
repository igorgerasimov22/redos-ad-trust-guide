# 1. Требования перед настройкой trust

## 1.1. Исходные данные

Перед началом зафиксируйте:

```text
IPA DNS domain:
IPA Kerberos realm:
IPA server FQDN:
IPA server IP:
IPA NetBIOS name:

AD DNS domain:
AD NetBIOS name:
AD DC FQDN:
AD DC IP:
AD account for trust:
```

Не используйте одинаковые NetBIOS-имена для IPA и AD.

## 1.2. Требования к учётной записи AD

Для стандартного создания trust через:

```bash
ipa trust-add ... --admin <account> --password
```

используйте AD-учётную запись с правами `Domain Admins`.

Практически удобно создать отдельную временную административную учётную запись для процедуры trust и после успешной настройки убрать лишние права.

## 1.3. DNS

Обе стороны должны разрешать DNS-имена друг друга.

На IPA:

```bash
getent hosts dc01.ad.example.local
nslookup dc01.ad.example.local

dig +short _ldap._tcp.ad.example.local SRV
dig +short _kerberos._tcp.ad.example.local SRV
```

Если AD имеет несколько DC, проверьте каждый возвращаемый SRV-записью контроллер.

Очень важный практический момент: `getent hosts` и `nslookup` могут показывать разные источники разрешения имени. При диагностике всегда проверяйте фактический адрес, к которому обращается приложение.

Неправильная запись в `/etc/hosts` способна полностью сломать trust даже при корректном DNS.

## 1.4. Условные DNS forwarders

### AD → IPA

На Windows DNS создайте Conditional Forwarder для IPA-домена на IP IPA DNS.

Пример:

```cmd
dnscmd 127.0.0.1 /ZoneAdd ipa.example /Forwarder 192.0.2.10
```

### IPA → AD

Если домены не разрешаются через общую DNS-инфраструктуру, создайте forward zone:

```bash
ipa dnsforwardzone-add ad.example.local \
  --forwarder=192.0.2.20 \
  --forward-policy=only
```

Проверка:

```bash
ipa dnsforwardzone-show ad.example.local
```

Не направляйте forwarder на устаревший или недоступный DC.

## 1.5. Время

Kerberos чувствителен к рассинхронизации времени.

На РЕД ОС:

```bash
date -Ins
timedatectl
chronyc tracking
chronyc sources -v
```

Проверка времени AD DC:

```bash
net time -S dc01.ad.example.local -U 'AD-EXAMPLE\trustadmin'
```

Цель — синхронизированные часы. Разницу лучше держать в пределах секунд.

## 1.6. IPv6

FreeIPA/Samba используют сетевые компоненты, которым нужен работающий IPv6 stack. Не отключайте IPv6 глобально через `ipv6.disable=1`, если нет отдельного подтверждённого требования.

## 1.7. Сетевые порты

Минимально проверьте IPA → AD DC:

```text
53/tcp+udp     DNS
88/tcp+udp     Kerberos
135/tcp        RPC Endpoint Mapper
389/tcp+udp    LDAP / CLDAP
445/tcp        SMB
464/tcp+udp    Kerberos password change
3268/tcp       Global Catalog
49152-65535/tcp Dynamic RPC (современный Windows Server)
```

Быстрый тест с IPA:

```bash
for p in 53 88 135 389 445 464 3268; do
  nc -vz dc01.ad.example.local "$p"
done
```

Для dynamic RPC нужен сетевой firewall, разрешающий соответствующий диапазон от IPA к AD DC.

Также AD DC должен иметь возможность обращаться к trust controller IPA по необходимым Samba/LDAP/Kerberos портам.

## 1.8. Предварительная проверка AD через Samba

Проверка LSA:

```bash
rpcclient -U 'AD-EXAMPLE\trustadmin' \
  dc01.ad.example.local \
  -c 'lsaquery'
```

Ожидается:

```text
Domain Name: AD-EXAMPLE
Domain Sid: S-1-5-21-...
```

Дополнительно:

```bash
smbclient -L //dc01.ad.example.local \
  -U 'AD-EXAMPLE\trustadmin'
```

Если видны `NETLOGON` и `SYSVOL`, SMB-аутентификация к AD работает.
