# Deployment of two FreeIPA servers with Ansible

The repository now contains an Ansible layout under `ansible/`.

The intended topology is two IPA servers in one realm:

```text
ipa01.ipa.example   primary / initial server
ipa02.ipa.example   replica
```

The first server is installed with `ipa-server-install`. The second is enrolled against the first and promoted with `ipa-replica-install`.

This is important: the second node must not be initialized as a separate standalone IPA realm.

## Preparation

1. Create two fresh RED OS 8 hosts.
2. Configure static IP addresses.
3. Ensure both FQDNs have correct forward and reverse DNS records.
4. Ensure time synchronization works.
5. Edit `ansible/inventory/hosts.yml`.
6. Edit `ansible/group_vars/ipa_servers.yml`.
7. Create encrypted `ansible/group_vars/vault.yml` from the example.

## Run

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --ask-vault-pass
```

After deployment, use `configure.yml` to manage directory objects without reinstalling the servers:

```bash
ansible-playbook configure.yml --ask-vault-pass
```

Directory-backed changes are made through one IPA server and replicated by FreeIPA to the second node.
