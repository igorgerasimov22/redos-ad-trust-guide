# 6. Troubleshooting

Ниже — ошибки, реально встретившиеся при настройке trust, и порядок их разбора.

---

## 6.1. `3221225581 / 0xC000006D / STATUS_LOGON_FAILURE`

Сообщение:

```text
Ошибка обмена данными с сервером CIFS:
код "3221225581"
The attempted logon is invalid...
```

### Проверять

1. Какой IP реально получает имя DC:

```bash
getent hosts dc01.ad.example.local
nslookup dc01.ad.example.local
```

2. `/etc/hosts`:

```bash
grep -n 'dc01' /etc/hosts
```

3. Порты:

```bash
nc -vz dc01.ad.example.local 135
nc -vz dc01.ad.example.local 445
nc -vz dc01.ad.example.local 389
nc -vz dc01.ad.example.local 3268
```

4. Credentials напрямую:

```bash
rpcclient -U 'AD-EXAMPLE\trustadmin' \
  dc01.ad.example.local \
  -c 'lsaquery'
```

5. SMB:

```bash
smbclient -L //dc01.ad.example.local \
  -U 'AD-EXAMPLE\trustadmin'
```

Если `rpcclient` и `smbclient` работают, простой неправильный пароль уже маловероятен.

### Важный случай: старый trust на AD

Если на Windows сохранился старый trust, а соответствующий объект/secret на IPA уже отсутствует, Samba может логировать проблемы secure channel, например ошибки получения machine password. Сначала сравните состояние обеих сторон.

---

## 6.2. `3221225485 / 0xC000000D / NT_STATUS_INVALID_PARAMETER`

Сообщение:

```text
Ошибка обмена данными с сервером CIFS:
код "3221225485"
An invalid parameter was passed to a service or function.
```

### Первое, что проверять на РЕД ОС

```bash
rpm -q samba
smbd -b | grep HAVE_KADM5SRV_MIT
```

Если `HAVE_KADM5SRV_MIT` отсутствует и установлен пакет с суффиксом `h`, переключите весь Samba-стек на MIT-сборку `m`.

Реально подтверждённый случай:

```text
samba-4.23.8-2h.red80
→ NT_STATUS_INVALID_PARAMETER
```

после перехода всех зависимых Samba RPM на:

```text
samba-4.23.8-1m.red80
HAVE_KADM5SRV_MIT
```

тот же trust был создан успешно и проверен.

### Не начинайте с ручного патчинга FreeIPA

Samba 4.23 действительно потребовала upstream-изменений FreeIPA в области forest trust, но в нашем случае ручные Python-патчи не устранили ошибку. Реальная причина оказалась в варианте сборки Samba РЕД ОС.

Поэтому при `INVALID_PARAMETER` порядок такой:

1. проверить `m/h`;
2. проверить согласованность всех Samba RPM;
3. проверить `HAVE_KADM5SRV_MIT`;
4. перезапустить/reboot;
5. повторить trust;
6. только затем углубляться в совместимость FreeIPA/Samba.

---

## 6.3. `ipa: ERROR: не получены учётные данные Kerberos`

Это локальная проблема IPA CLI, а не AD.

```bash
kinit admin
klist
ipa ping
```

---

## 6.4. `Cannot contact any KDC for realm`

Проверьте состояние IPA:

```bash
ipactl status
```

Если Directory Service/KDC/httpd остановлены:

```bash
ipactl restart
ipactl status
```

После этого:

```bash
kinit admin
ipa ping
```

---

## 6.5. После reboot IPA сервисы STOPPED

Пример:

```text
Directory Service: RUNNING
krb5kdc: RUNNING
httpd: STOPPED
smb: STOPPED
winbind: STOPPED
```

Штатное действие:

```bash
ipactl restart
ipactl status
```

Не включайте вручную `smb`/`winbind` через systemd, пока не проверили штатное управление через `ipactl`.

---

## 6.6. Нет локального listener `135/tcp`

Проверка:

```bash
ss -lntp | grep -E ':(135|445)\b'
```

В современных Samba `samba-dcerpcd`/`rpcd_*` могут запускаться on-demand.

Пакетная проверка:

```bash
rpm -ql samba-dcerpc | grep -E 'samba-dcerpcd|rpcd_'
```

Обычно бинарники расположены в:

```text
/usr/libexec/samba/samba-dcerpcd
/usr/libexec/samba/rpcd_epmapper
/usr/libexec/samba/rpcd_lsad
...
```

Отсутствие `command -v samba-dcerpcd` не означает, что бинарник не установлен: `/usr/libexec/samba` обычно не входит в `$PATH`.

Не создавайте самодельный systemd unit без отдельного доказательства необходимости.

---

## 6.7. DNS указывает на старый/неправильный DC

Очень характерный сценарий:

```text
getent hosts dc01.ad.example.local
→ старый IP

nc ...
→ No route to host
```

Исправьте DNS или ошибочную запись `/etc/hosts`, затем повторите:

```bash
getent hosts dc01.ad.example.local
nc -vz dc01.ad.example.local 135
nc -vz dc01.ad.example.local 445
nc -vz dc01.ad.example.local 389
nc -vz dc01.ad.example.local 3268
```

---

## 6.8. AD имеет несколько DC

Проверьте SRV:

```bash
dig +short _ldap._tcp.ad.example.local SRV
dig +short _kerberos._tcp.ad.example.local SRV
```

Проверяйте сеть до каждого DC.

Во время диагностики можно зафиксировать конкретный рабочий DC:

```bash
ipa trust-add ad.example.local \
  ... \
  --server=dc01.ad.example.local
```

Это убирает случайный выбор другого DC как переменную.

---

## 6.9. Логи FreeIPA/Samba

FreeIPA API:

```bash
grep -Ei \
'CIFS|dcerpc|NT_STATUS|INVALID_PARAMETER|trust|lsa|Traceback|ERROR' \
/var/log/httpd/error_log | tail -n 150
```

Systemd:

```bash
journalctl --since '-10 min' \
  -u httpd -u smb -u winbind \
  --no-pager
```

Для живого наблюдения:

```bash
tail -F /var/log/httpd/error_log
```

и в другом терминале запустить `ipa trust-add`.

---

## 6.10. Проверить, не осталось ли частично созданных объектов

IPA:

```bash
ipa trust-find
ipa idrange-find
```

AD:

```powershell
Get-ADTrust -Filter * |
  Select Name,Source,Target,Direction,TrustType,TrustAttributes
```

Не удаляйте объекты автоматически. Сначала определите, на какой стороне реально существует trust.

---

## 6.11. Проверить Windows Security log

Если подозрение остаётся на AD authentication, найдите событие `4625` в момент `trust-add` и проверьте:

- Account Name
- Account Domain
- Logon Type
- Status
- SubStatus
- Authentication Package
- Logon Process
- Source Network Address

Если во время неудачного `trust-add` на AD вообще нет `4625`, ошибка может происходить локально на IPA/Samba до удалённой проверки credentials.
