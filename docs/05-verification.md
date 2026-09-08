# 5. Проверка после создания trust

## 5.1. Проверка на IPA

```bash
ipa trust-show ad.example.local
ipa trustdomain-find ad.example.local
```

## 5.2. Проверка разрешения AD-пользователя

```bash
id 'user@ad.example.local'
getent passwd 'user@ad.example.local'
```

Проверяйте не только Domain Admin, но и обычного пользователя.

Если `id` возвращает UID/GID и группы, работает цепочка:

```text
AD → Trust → FreeIPA/SSSD → SID mapping → POSIX identity
```

## 5.3. Проверка trust на Windows

PowerShell:

```powershell
Get-ADTrust -Identity "IPA.EXAMPLE" |
  Format-List Name,Source,Target,Direction,TrustType,TrustAttributes
```

Проверка общего списка:

```cmd
nltest /domain_trusts
```

Для двустороннего trust ожидается соответствующее направление `BiDirectional` / двустороннее.

## 5.4. Проверка сервисов после reboot

```bash
ipactl status
```

Если после загрузки:

```text
Directory Service: STOPPED
```

или часть служб не запустилась, сначала:

```bash
ipactl restart
ipactl status
```

а уже затем проверяйте пользователей/trust.

## 5.5. Зафиксировать версии рабочего стека

После успешного запуска сохраните версии:

```bash
rpm -q \
  ipa-server \
  ipa-server-trust-ad \
  samba \
  samba-dcerpc \
  samba-winbind \
  python3-samba

smbd -b | grep HAVE_KADM5SRV_MIT
```

Это сильно ускоряет диагностику после будущих обновлений.
