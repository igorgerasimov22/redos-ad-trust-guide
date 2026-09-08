# 3. Подготовка Windows Server 2019 AD

## 3.1. DNS: AD должен видеть IPA

На DNS-сервере Windows создайте Conditional Forwarder для IPA-домена.

GUI:

1. DNS Manager.
2. Conditional Forwarders.
3. New Conditional Forwarder.
4. Указать IPA DNS domain.
5. Добавить IP IPA DNS server.
6. При необходимости сохранить forwarder в AD и реплицировать на DNS-серверы леса.

CLI-пример:

```cmd
dnscmd 127.0.0.1 /ZoneAdd ipa.example /Forwarder 192.0.2.10
```

Проверка:

```powershell
Resolve-DnsName ipa01.ipa.example
Resolve-DnsName -Type SRV _ldap._tcp.ipa.example
Resolve-DnsName -Type SRV _kerberos._tcp.ipa.example
```

## 3.2. IPA должен видеть AD

Со стороны IPA проверьте A/AAAA и SRV:

```bash
getent hosts dc01.ad.example.local

dig +short _ldap._tcp.ad.example.local SRV
dig +short _kerberos._tcp.ad.example.local SRV
```

Если AD имеет два или больше DC, проверьте доступность **каждого** DC, который возвращается SRV-записями.

Для диагностического создания trust можно явно закрепить проверенный DC через:

```text
--server=dc01.ad.example.local
```

## 3.3. Windows Firewall / сетевой firewall

Для AD trust требуются, среди прочего:

```text
53 TCP/UDP        DNS
88 TCP/UDP        Kerberos
135 TCP           RPC Endpoint Mapper
389 TCP/UDP       LDAP/CLDAP
445 TCP           SMB
464 TCP/UDP       Kerberos password change
3268 TCP          Global Catalog
49152-65535 TCP   Dynamic RPC on modern Windows Server
```

В корпоративной сети правила лучше ограничить адресами IPA trust controllers и AD DC.

Microsoft отдельно указывает dynamic RPC для LSA/SAM/Netlogon. Простого открытия `135/tcp` недостаточно, если dynamic RPC блокируется между серверами.

## 3.4. Учётная запись для создания trust

Для стандартного:

```bash
ipa trust-add --admin trustadmin --password
```

используйте AD-учётную запись, входящую в `Domain Admins`.

Проверка на Windows:

```powershell
Get-ADUser trustadmin -Properties MemberOf | Select-Object SamAccountName,MemberOf
```

## 3.5. Проверить, не остался ли старый trust

После неудачных экспериментов перед повторным созданием проверьте:

```powershell
Get-ADTrust -Filter * |
  Select-Object Name,Source,Target,Direction,TrustType,TrustAttributes
```

Если старый trust к IPA был создан вручную или остался после предыдущей попытки, его состояние может мешать диагностике.

Не удаляйте trust автоматически: сначала сравните состояние на обеих сторонах.

На IPA:

```bash
ipa trust-find
ipa idrange-find
```

На AD:

```powershell
Get-ADTrust -Filter *
```

После осознанной очистки обе стороны должны быть согласованы.
