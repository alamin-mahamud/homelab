- Update Inventories
- Copy over the SSH Public key to all the managed hosts `ssh-copy-id <ip>`
- Run playbook

```
ansible-playbook -i ./ansible/inventories/k8s.ini ./ansible/playbooks/k8s/cluster.yml
```

```
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -i ./inventories/hosts/etcd.ini ./playbooks/etcd.yaml -e debug_mode=true
```
