# RED OS ↔ Windows Server 2019 AD Trust Guide

Практическая инструкция по созданию двустороннего доверия между FreeIPA/IdM на РЕД ОС 8 и Microsoft Active Directory на Windows Server 2019.

Инструкция собрана на основе реальной диагностики рабочего стенда и сверена с документацией РЕД ОС, FreeIPA и Microsoft.

## Проверенная конфигурация

Рабочий результат получен на следующем стеке:

- РЕД ОС 8
- FreeIPA / IdM `4.12.2`
- `ipa-server-trust-ad 4.12.2`
- Samba `4.23.8-1m.red80`
- Windows Server 2019 Active Directory
- двустороннее forest trust

Критически важно: Samba на IPA-сервере должна быть собрана с **MIT Kerberos**. В пакетах РЕД ОС такая сборка имеет суффикс `m` и должна показывать:

```bash
smbd -b | grep HAVE_KADM5SRV_MIT
```

Ожидаемый результат:

```text
HAVE_KADM5SRV_MIT
```

В реальном разборе сборка `4.23.8-2h.red80` приводила к `NT_STATUS_INVALID_PARAMETER`, а переход всего Samba-стека на `4.23.8-1m.red80` сразу позволил создать и проверить двусторонний trust.

## Структура репозитория

- [`docs/01-prerequisites.md`](docs/01-prerequisites.md) — требования к DNS, времени, именам, учётной записи и сетевой связности.
- [`docs/02-redos-preparation.md`](docs/02-redos-preparation.md) — подготовка РЕД ОС, FreeIPA, Samba и `ipa-adtrust-install`.
- [`docs/03-windows-preparation.md`](docs/03-windows-preparation.md) — DNS и firewall на Windows Server 2019.
- [`docs/04-create-trust.md`](docs/04-create-trust.md) — создание двустороннего доверия.
- [`docs/05-verification.md`](docs/05-verification.md) — проверка trust и разрешения пользователей AD.
- [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md) — ошибки и диагностика, включая проблемы, найденные в реальном стенде.
- [`docs/SOURCES.md`](docs/SOURCES.md) — официальные источники.
- [`scripts/precheck-redos.sh`](scripts/precheck-redos.sh) — автоматический предварительный чек IPA-сервера.
- [`scripts/verify-trust.sh`](scripts/verify-trust.sh) — пост-проверка trust.

## Обозначения в примерах

Замените значения на свои:

```text
IPA domain:      ipa.example
IPA realm:       IPA.EXAMPLE
IPA server:      ipa01.ipa.example
IPA NetBIOS:     IPAEXAMPLE
IPA IP:          192.0.2.10

AD domain:       ad.example.local
AD NetBIOS:      AD-EXAMPLE
AD DC:           dc01.ad.example.local
AD DC IP:        192.0.2.20
AD admin:        trustadmin
```

NetBIOS-имена IPA и AD должны быть различными.

## Короткая последовательность

### 1. Проверить DNS и время

На IPA:

```bash
hostname -f
getent hosts dc01.ad.example.local
dig +short _ldap._tcp.ad.example.local SRV
dig +short _kerberos._tcp.ad.example.local SRV
timedatectl
chronyc tracking
```

На AD проверить разрешение IPA-домена и SRV-записей.

### 2. Проверить Samba с MIT Kerberos

```bash
rpm -q samba ipa-server ipa-server-trust-ad
smbd -b | grep HAVE_KADM5SRV_MIT
```

Если `HAVE_KADM5SRV_MIT` отсутствует — **trust не создавайте**. Сначала переключите Samba на MIT-сборку `m`.

### 3. Настроить IPA как trust controller

```bash
dnf install ipa-server-trust-ad
kinit admin
ipa-adtrust-install
ipactl restart
ipactl status
```

### 4. Проверить связь IPA → AD

```bash
nc -vz dc01.ad.example.local 88
nc -vz dc01.ad.example.local 135
nc -vz dc01.ad.example.local 389
nc -vz dc01.ad.example.local 445
nc -vz dc01.ad.example.local 3268
```

Проверить AD-учётную запись через Samba:

```bash
rpcclient -U 'AD-EXAMPLE\trustadmin' dc01.ad.example.local -c 'lsaquery'
```

При успехе должны вернуться имя AD-домена и его SID.

### 5. Создать двусторонний trust

```bash
kinit admin

ipa trust-add ad.example.local \
  --type=ad \
  --range-type=ipa-ad-trust \
  --admin=trustadmin \
  --password \
  --two-way=true \
  --server=dc01.ad.example.local
```

Успешный результат должен содержать:

```text
Направление отношения доверия: Двустороннее отношение доверия
Состояние отношения доверия: Установлено и проверено
```

### 6. Обновить и проверить доверенные домены

```bash
ipa trust-fetch-domains ad.example.local
ipa trust-show ad.example.local
ipa trustdomain-find ad.example.local
```

### 7. Проверить пользователя AD

```bash
id 'user@ad.example.local'
getent passwd 'user@ad.example.local'
```

## Главный практический вывод

При работе FreeIPA на РЕД ОС нельзя ориентироваться только на номер версии Samba. Нужно проверить **тип сборки**.

Плохо для данного сценария:

```text
samba-4.23.8-2h.red80
```

Рабочий вариант на протестированном стенде:

```text
samba-4.23.8-1m.red80
HAVE_KADM5SRV_MIT
```

После получения рабочего состояния имеет смысл исключить Samba из обычного обновления до тех пор, пока не будет подтверждено, что новая версия остаётся MIT-сборкой и совместима с установленной FreeIPA.

См. подробности в [`docs/02-redos-preparation.md`](docs/02-redos-preparation.md) и [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md).
