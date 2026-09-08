# 2. Подготовка РЕД ОС и FreeIPA

## 2.1. Установить trust-компоненты

```bash
dnf install ipa-server-trust-ad
```

Проверьте версии:

```bash
rpm -q \
  ipa-server \
  ipa-server-trust-ad \
  samba \
  samba-dcerpc \
  samba-winbind \
  python3-samba
```

## 2.2. Критически важная проверка Samba: MIT Kerberos

РЕД ОС для trust IPA↔MSAD требует Samba с MIT Kerberos.

Проверка:

```bash
smbd -b | grep HAVE_KADM5SRV_MIT
```

Должно быть:

```text
HAVE_KADM5SRV_MIT
```

В имени RPM РЕД ОС MIT-сборка имеет суффикс `m`.

Пример рабочего стека:

```text
samba-4.23.8-1m.red80
samba-dcerpc-4.23.8-1m.red80
samba-winbind-4.23.8-1m.red80
python3-samba-4.23.8-1m.red80
```

### Почему это важно

В реальной диагностике весь стек находился на:

```text
4.23.8-2h.red80
```

и `ipa trust-add` стабильно возвращал:

```text
3221225485 / 0xC000000D
NT_STATUS_INVALID_PARAMETER
An invalid parameter was passed to a service or function.
```

После согласованного перехода **всех Samba-пакетов** на:

```text
4.23.8-1m.red80
```

и появления `HAVE_KADM5SRV_MIT` тот же `ipa trust-add` сразу завершился сообщением:

```text
Состояние отношения доверия: Установлено и проверено
```

Поэтому не пытайтесь лечить `INVALID_PARAMETER` ручными изменениями `smb.conf`, systemd units или Python-кода FreeIPA до проверки варианта сборки Samba.

## 2.3. Проверить доступные Samba-сборки

```bash
dnf --showduplicates list \
  samba \
  samba-dcerpc \
  samba-winbind \
  samba-client \
  python3-samba \
  samba-common-libs \
  samba-client-libs \
  samba-libs \
  libwbclient \
  libsmbclient
```

Если текущая версия имеет `h`, а в репозитории есть соответствующая `m`, сначала сделайте dry-run:

```bash
dnf downgrade samba-4.23.8-1m.red80 --assumeno
```

Убедитесь, что DNF переводит **весь согласованный Samba-стек**, а не один пакет.

После проверки:

```bash
dnf downgrade samba-4.23.8-1m.red80
```

Не допускайте смеси вроде:

```text
samba 4.23.8-1m
python3-samba 4.23.8-2h
samba-libs 4.23.8-2h
```

После транзакции:

```bash
rpm -qa | grep -E \
'^(samba|python3-samba|libsmbclient|libwbclient|libnetapi)' | sort

smbd -b | grep HAVE_KADM5SRV_MIT
```

Документация РЕД ОС также рекомендует команду:

```bash
dnf dg samba
```

для переключения Samba на MIT-сборку. На конкретной системе сначала смотрите план транзакции и итоговые версии.

## 2.4. Не обновлять Samba вслепую

Обычная установка дополнительного Samba-пакета может потянуть замену всего Samba-стека на другую сборку.

Например:

```bash
dnf install samba-client
```

может не просто добавить клиент, а обновить `samba`, `python3-samba`, `winbind`, библиотеки и `dcerpc`.

Перед изменениями на production-сервере используйте:

```bash
dnf install samba-client --assumeno
```

или изучайте транзакцию до подтверждения.

После получения рабочего trust РЕД ОС рекомендует исключить Samba из обычных обновлений:

```ini
exclude=libsmbclient libwbclient python3-samba python3-samba-dc samba*
```

Перед добавлением проверьте существующие `exclude=`:

```bash
grep -n '^exclude=' /etc/dnf/dnf.conf
```

## 2.5. Настроить IPA как AD trust controller

Получите Kerberos ticket IPA admin:

```bash
kinit admin
klist
```

Настройте trust-компоненты:

```bash
ipa-adtrust-install
```

В штатном сценарии подтвердите предлагаемые настройки.

Если AD-пользователи должны обслуживаться через несколько IPA masters, `ipa-adtrust-install` следует выполнить на каждом IPA-сервере, к которому будут обращаться клиенты.

## 2.6. Перезапустить IPA

```bash
ipactl restart
ipactl status
```

Ожидайте `RUNNING` как минимум для:

```text
Directory Service
krb5kdc
kadmin
httpd
ipa-custodia
smb
winbind
```

Если после reboot часть служб `STOPPED`, сначала выполните:

```bash
ipactl restart
```

и только после успешного `ipactl status` продолжайте trust.

## 2.7. Проверить Samba/RPC процессы

```bash
ss -lntp | grep -E ':(135|445)\b'

ps -ef | grep -E \
'smbd|winbindd|samba-dcerpcd|rpcd_' | grep -v grep
```

В Samba 4.23 `samba-dcerpcd` и `rpcd_*` могут запускаться on-demand. Не создавайте вручную systemd unit для `samba-dcerpcd`, пока не доказано, что штатный пакетный механизм неисправен.
