# 4. Создание двустороннего trust

## 4.1. Проверить состояние IPA

```bash
ipactl status
```

Все IPA/trust-службы должны быть `RUNNING`.

## 4.2. Получить Kerberos ticket IPA admin

```bash
kdestroy 2>/dev/null || true
kinit admin
klist
```

Ожидается principal:

```text
admin@IPA.EXAMPLE
```

Проверить IPA API:

```bash
ipa ping
```

Если вместо trust-ошибки вы получили:

```text
не получены учётные данные Kerberos
```

проблема ещё не дошла до Active Directory — сначала нужен `kinit admin`.

## 4.3. Проверить AD credentials отдельно

```bash
rpcclient -U 'AD-EXAMPLE\trustadmin' \
  dc01.ad.example.local \
  -c 'lsaquery'
```

При успехе:

```text
Domain Name: AD-EXAMPLE
Domain Sid: S-1-5-21-...
```

Это подтверждает сетевую доступность, SMB/RPC-аутентификацию и корректность логина/пароля. Оно не заменяет проверку прав на создание trust, но хорошо отделяет auth-проблему от остальных.

## 4.4. Создать trust

Рекомендуемый диагностически однозначный вариант — указать конкретный проверенный DC:

```bash
ipa trust-add ad.example.local \
  --type=ad \
  --range-type=ipa-ad-trust \
  --admin=trustadmin \
  --password \
  --two-way=true \
  --server=dc01.ad.example.local
```

FreeIPA сам преобразует обычное имя `trustadmin` в Samba-style credential с NetBIOS удалённого домена. Нет необходимости без причины заменять его на UPN или вручную добавлять домен в `--admin`.

## 4.5. Ожидаемый успешный результат

```text
Добавлено отношение доверия Active Directory для области (realm) "ad.example.local"

Имя области (realm): ad.example.local
Имя домена NetBIOS: AD-EXAMPLE
Идентификатор безопасности домена: S-1-5-21-...
Направление отношения доверия: Двустороннее отношение доверия
Тип отношения доверия: Домен Active Directory
Состояние отношения доверия: Установлено и проверено
```

Ключевая строка:

```text
Состояние отношения доверия: Установлено и проверено
```

## 4.6. Обновить список доменов доверенного леса

```bash
ipa trust-fetch-domains ad.example.local
```

Проверить:

```bash
ipa trust-show ad.example.local
ipa trustdomain-find ad.example.local
```
