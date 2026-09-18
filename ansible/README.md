# Ansible: deployment and management of two FreeIPA servers

This directory provides an Ansible baseline for a two-node FreeIPA/IdM deployment on RED OS 8.

Topology:

- `ipa01` — initial IPA server (bootstrap master)
- `ipa02` — IPA replica
- DNS integrated with IPA on both nodes
- CA installed on both nodes
- configuration changes are applied through Ansible after deployment

## Requirements

On the Ansible controller:

```bash
python3 -m pip install ansible
ansible-galaxy collection install -r requirements.yml
```

The managed hosts must be fresh RED OS 8 machines with static IPs, working forward/reverse DNS and synchronized time.

## Files

- `inventory/hosts.yml` — two IPA hosts.
- `group_vars/ipa_servers.yml` — non-secret IPA settings.
- `group_vars/vault.yml.example` — secret variable template.
- `requirements.yml` — required collections.
- `site.yml` — deploy both IPA servers.
- `configure.yml` — apply IPA users/groups/HBAC/sudo/DNS changes.
- `roles/ipa_common` — common OS preparation.
- `roles/ipa_server` — bootstrap the first IPA server.
- `roles/ipa_replica` — join the second server as a replica.
- `roles/ipa_config` — declarative IPA configuration.

## Secrets

Create an encrypted Vault file:

```bash
cp group_vars/vault.yml.example group_vars/vault.yml
ansible-vault encrypt group_vars/vault.yml
```

Never commit `group_vars/vault.yml`.

## Deploy

Edit the inventory and variables, then run:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

The playbook installs `ipa01` first, then creates `ipa02` as a replica. This ordering is intentional.

## Change IPA configuration

Define objects in `group_vars/ipa_servers.yml` and run:

```bash
ansible-playbook -i inventory/hosts.yml configure.yml --ask-vault-pass
```

Configuration is executed against the first IPA node only. FreeIPA replicates directory-backed changes to the second server.

## Idempotency

The roles check whether IPA is already configured before running installation commands. Re-running `site.yml` should therefore not reinstall an existing topology.
