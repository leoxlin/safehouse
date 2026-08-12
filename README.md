# safehouse

My collection of dotfiles and configs to help set up new machines. Configs are
platform agnostic but OSX might require karabiner to properly work.

- `setup.sh` - run the setup script
- `dot.sh` - run the symlink script in dry-run
- `dot.sh apply` - run the symlink script and apply

## Manage workstations

Install Ansible and its collections:

```sh
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yaml
```

Apply the complete workstation configuration, or only the core role:

```sh
cd ansible
ansible-playbook playbooks/workstation.yaml
ansible-playbook playbooks/core.yaml
```
