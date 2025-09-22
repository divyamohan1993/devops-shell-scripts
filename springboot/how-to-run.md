```
# basic (HTTP only), debug ON (default)
sudo DEBUG=1 ./oneclick-deploy-enterprise.sh

# enable TLS:
sudo DOMAIN=app.example.com EMAIL=admin@example.com ./oneclick-deploy-enterprise.sh

# canary 10%, later promote:
sudo CANARY_PERCENT=10 ./oneclick-deploy-enterprise.sh
sudo PROMOTE=1 ./oneclick-deploy-enterprise.sh

# rollback to previous:
sudo ROLLBACK=1 ./oneclick-deploy-enterprise.sh
```