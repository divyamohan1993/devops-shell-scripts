```bash
    1  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    2  # Add Docker's official GPG key:
    3  sudo apt-get update
    4  sudo apt-get install ca-certificates curl
    5  sudo install -m 0755 -d /etc/apt/keyrings
    6  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    7  sudo chmod a+r /etc/apt/keyrings/docker.asc
    8  # Add the repository to Apt sources:
    9  echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
   10    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   11  sudo apt-get update
   12  sudo apt update
   13  sudo apt upgrade
   14  # Add Docker's official GPG key:
   15  sudo apt-get update
   16  sudo apt-get install ca-certificates curl
   17  sudo install -m 0755 -d /etc/apt/keyrings
   18  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   19  sudo chmod a+r /etc/apt/keyrings/docker.asc
   20  # Add the repository to Apt sources:
   21  echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
   22    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   23  sudo apt-get update
   24  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   25  sudo docker run hello-world
   26  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/maven-gradle-sanity/run-latest.sh
   27  chmod +x run-latest.sh 
   28  ./run-latest.sh 
   29  sudo ./run-latest.sh 
   30  docker login
   31  sudo docker pull nginx
   32  docker run nginx
   33  sudo docker run nginx
   34  sudo docker imager
   35  sudo docker images
   36  sudo docker ps
   37  sudo docker ps -a
   38  sudo docker run -d nginx
   39  sudo docker ps
   40  sudo docker stop boring_einstein
   41  sudo docker ps
   42  sudo docker ps -
   43  sudo docker ps -a
   44  docker rm admiring_gould
   45  sudo docker rm admiring_gould
   46  sudo docker run --rm -d nginx
   47  sudo docker ps
   48  sudo docker stop admiring_torvalds
   49  sudo docker ps
   50  sudo docker ps -a
   51  sudo docker rm boring_einstein
   52  sudo docker ps -a
   53  sudo docker run -it --name ubu ubuntu
   54  sudo docker rm -f ubu
   55  sudo docker ps -a
   56  docker pull kalilinux/kali-rolling
   57  sudo docker pull kalilinux/kali-rolling
   58  sudo docker run -rm kali
   59  sudo docker run -rm kalilinux
   60  sudo docker run --rm kalilinux
   61  sudo docker imag
   62  sudo docker run --rm kalilinux/kali-rolling
   63  sudo docker run -it --rm kalilinux/kali-rolling
   64  sudo docker ps -a
   65  sudo docker ps
   66  sudo docker pull ubuntu/apache2
   67  sudo docker run -p 8090:80 ubuntu/apache2
   68  sudo docker run -p -d 8090:80 ubuntu/apache2
   69  sudo docker run -d -p 8090:80 ubuntu/apache2
   70  sudo docker ps -a
   71  sudo docker rm vibrant_torvalds
   72  sudo su
   73  sudo docker run -d -p 8090:80 ubuntu/apache2
   74  sudo docker ps -a
   75  sudo docker rm -f intelligent_torvalds
   76  sudo docker run -d -it -p 8090:80 ubuntu/apache2
   77  sudo docker run -it -p 8090:80 ubuntu/apache2
   78  sudo docker ps
   79  sudo docker wizardly_hertz
   80  sudo docker rm -f wizardly_hertz
   81  sudo docker run -it -p 8090:80 ubuntu/apache2
   82  sudo docker run --rm -it -p 8090:80 ubuntu/apache2 /bin/bash
   83  sudo docker run --rm -it -p 8090:80 ubuntu/apache2 bash
   84  sudo docker rm -f $(sudo docker ps -q)
   85  sudo docker rm -f sudo docker ps -q | xargs -r sudo docker rm -f$(sudo docker ps -q)
   86  sudo docker ps
   87  sudo docker run --rm -it -p 8090:80 ubuntu/apache2 /bin/bash
   88  sudo docker rm -f $(sudo docker ps -q)
   89  docker logs
   90  docker network ls
   91  sudo docker network ls
   92  sudo docker run -d --name app1 --network bridge nginx
   93  sudo docker ps
   94  sudo docker exec appi bash
   95  sudo docker exec app1 bash
   96  sudo docker exec app1 bash -t
   97  ssudo docker network create bridgenetwork
   98  sudo docker run -d --name app1 --network bridge apache2
   99  sudo docker run -d --rm --network host nginx
  100  sudo docker network create -d host 
  101  sudo docker network create bridgenetwork
  102  sudo docker run -d --rm --name app1 --network bridgenetwork apache2
  103  sudo docker ps
  104  sudo docker login
  105  docker ps
  106  sudo docker ps
  107  sudo docker run -d -it --rm --name htc --network host nginx
  108  sudo docker exec htc base
  109  sudo docker exec htc bash
  110  docker ps
  111  sudo docker ps
  112  sudo docker run -d -it --rm --name htc  nginx
  113  sudo docker ps
  114  sudo docker exec htc bash
  115  sudo docker exec htc /bin/bash
  116  sudo docker rm -f htc
  117  sudo docker rm -f app1
  118  sudo docker rm -f eloquent_lehmann
  119  sudo docker ps
  120  sudo docker run -it -d ifconfig
  121  ifconfig
  122  ip
  123  ip -a
  124  ip a
  125  docker run -it --rm ubuntu
  126  sudo docker run -it --rm ubuntu
  127  # 1) Start a DinD daemon container
  128  docker rm -f dind 2>/dev/null || true
  129  docker network create dindnet 2>/dev/null || true
  130  docker run -d --name dind --network dindnet   --privileged   --restart unless-stopped   --cgroupns=host   -v dind-storage:/var/lib/docker   -v /sys/fs/cgroup:/sys/fs/cgroup:rw   -e DOCKER_TLS_CERTDIR=   docker:28-dind
  131  # 2) Verify DinD works
  132  docker exec dind docker version
  133  docker exec dind docker run --rm hello-world
  134  # 3) Your Ubuntu 'work' container talks to DinD over TCP
  135  docker rm -f ubuntu-work 2>/dev/null || true
  136  docker run -it --name ubuntu-work --network dindnet   -e DOCKER_HOST=tcp://dind:2375   ubuntu:24.04 bash
  137  # (inside ubuntu-work)
  138  apt-get update && apt-get install -y docker.io   # or docker-cli
  139  docker run --rm hello-world
  140  # From the host:
  141  docker commit dfa8eb4e5da0 ubuntu-dind:work
  142  docker rm -f dfa8eb4e5da0
  143  docker run -d --name ubuntu-dind   --privileged --cgroupns=host   -v dind-storage:/var/lib/docker   -v /sys/fs/cgroup:/sys/fs/cgroup:rw   ubuntu-dind:work dockerd
  144  # Test:
  145  docker exec ubuntu-dind docker run --rm hello-world
  146  docker run -d --network bridge ubuntu
  147  sudo docker run -d --network bridge ubuntu
  148  sudo docker run -d --network bridge kalilinux/kali-rolling
  149  sudo docker run -d --network bridge nginx
  150  sudo docker run -it -d --name tester  --network bridge nginx
  151  sudo docker run -it -d --name testable  --network bridge ubuntu
  152  sudo docker run -it -d --name testable  --network bridge kalilinux/kali-rolling
  153  sudo docker run -it -d --name testablekali  --network bridge kalilinux/kali-rolling
  154  sodu docker ps
  155  sudo docker ps
  156  sudo docker run -it --name alpine --network bridge alpine
  157  nano Dockerfile
  158  sudo nano Dockerfile
  159  exit
  160  nano Dockerfile
  161  sudo apt update
  162  sudo apt install nano
  163  nano Dockerfile
  164  docker build -t myapache .
  165  sudo docker build -t myapache .
  166  nano Dockerfile
  167  sudo docker build -t myapache .
  168  nano Dockerfile
  169  sudo docker build -t myapache .
  170  docker run -p 8989:80 myapache
  171  sudo docker run -p 8989:80 myapache
  172  mkdir nginx
  173  cd nginx/
  174  nano Dockerfile
  175  docker build -t mynginx .
  176  docker run -p 8990:80 mynginx
  177  sudo docker run -p 8990:80 mynginx
  178  docker login
  179  sudo docker run -p 8990:80 mynginx
  180  nano Dockerfile
  181  docker build -t mynginx .
  182  sudo docker build -t mynginx .
  183  docker run -p 8990:80 mynginx
  184  sudo docker run -p 8990:80 mynginx
  185  nano Dockerfile
  186  sudo docker build -t mynginx .
  187  sudo docker run -p 8990:80 mynginx
  188  history
  189  history > index.txt
  190  python3 -m http.server 8080
  191  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/jenkins/autoconfig.sh
  192  chmod  +x autoconfig.sh
  193  ./autoconfig.sh 
  194  sudo ./autoconfig.sh 
  195  bash autoconfig.sh.1 
  196  sudo bash autoconfig.sh.1 
  197  # Add Docker's official GPG key:
  198  sudo apt-get update
  199  sudo apt-get install ca-certificates curl
  200  sudo install -m 0755 -d /etc/apt/keyrings
  201  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  202  sudo chmod a+r /etc/apt/keyrings/docker.asc
  203  # Add the repository to Apt sources:
  204  echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  205    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  206  sudo apt-get update
  207  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  208  sudo docker run hello-world
  209  # Ubuntu
  210  sudo apt-get update
  211  sudo apt-get install -y docker.io
  212  sudo usermod -aG docker jenkins
  213  sudo systemctl restart jenkins
  214  # (log out/in your shell session if you also use the CLI)
  215  history > history.html && python3 -m http.server 34567
  216  history > history.html
  217  python3 -m http.server 8910
  218  cat history.html 
  219  docker --version
  220  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  221  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  222  kubectl version --client
  223  sudo apt update
  224  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  225  kubectl cluster-info
  226  kubectl cluster-info dump
  227  sudo kubectl cluster-info dump
  228  sudo apt-get update
  229  # apt-transport-https may be a dummy package; if so, you can skip that package
  230  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  231  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  232  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
  233  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  234  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
  235  sudo apt-get update
  236  sudo apt-get install -y kubectl
  237  kubectl cluster-info
  238  curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
  239  sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
  240  minikube start
  241  kubectl config view
  242  mkdir -p ~/.kube
  243  sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
  244  sudo chown $(id -u):$(id -g) ~/.kube/configmkdir -p ~/.kube
  245  sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
  246  sudo chown $(id -u):$(id -g) ~/.kube/config
  247  sudo mkdir -p ~/.kube
  248  sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
  249  sudo chown $(id -u):$(id -g) ~/.kube/config
  250  sudo usermod -aG docker $USER
  251  newgrp docker
  252  minikube start
  253  rm ~/.minikube/config/config.json
  254  sudo rm ~/.minikube/config/config.json
  255  rm ~/.minikube/config/config.json
  256  minikube start
  257  cat ~/.minikube/config/config.json
  258  rm -rf ~/.minikube
  259  minikube start
  260  history
  261  history || grep "usermod"
  262  grep "usermod" || history
  263  kubectl get po -A
  264  minikube kubectl -- get po -A
  265  minikube dashboard
  266  minikube status
  267  kubectl create deployment nginx --image=nginx
  268  kubectl get deployment
  269  kubectl get pods
  270  minikube dashboard --url
  271  docker ps
  272  kubectl port-forward --address 0.0.0.0 svc/nginx port:8084
  273  kubectl port-forward --address 0.0.0.0
  274  sudo apt update
  275  sudo apt-get update
  276  sudo apt install nodejs npm -q
  277  mkdir reactapp && cd reactapp
  278  npx create-react-app nameofreactapp
  279  ~ls
  280  ls
  281  cd nameofreactapp/
  282  npm start
  283  npm run build
  284  npm start
  285  ls
  286  cd reactapp/
  287  ls
  288  cd nameofreactapp/
  289  ls
  290  cd src
  291  ls
  292  code .
  293  sudo apt install code
  294  sudo apt install vscode
  295  sudo apt install gh git
  296  git config --global user.name "Divya Mohan"
  297  git config --global user.email "divyamohan1993@gmail.com"
  298  gh repo create react-app-k8s --public --source=. --remote=origin --push
  299  cd ..
  300  ls
  301  rm -rf node_modules/
  302  ls
  303  gh auth login
  304  gh repo create react-app-k8s --public --source=. --remote=origin --push
  305  gh repo create
  306  ls
  307  gh 
  308  gh repo create react-app-k8s --public --source=. --remote=origin --push
  309  git init
  310  gh repo create react-app-k8s --public --source=. --remote=origin --push
  311  git commit 'test'
  312  git commit
  313  git add .
  314  git commit
  315  git commit 'test'
  316  git commit test
  317  git commit
  318  y
  319  rm -rf react-k8s-lnt
  320  git init
  321  git branch -M main
  322  cat > .gitignore << 'EOF'
EOF
  323  node_modules/
  324  build/
  325  dist/
  326  .env
  327  .DS_Store
  328  npm-debug.log*
  329  yarn-debug.log*
  330  yarn-error.log*
  331  EOF
  332  git add .
  333  git commit -m "Initial commit: React app for k8s demo"
  334  git remote -v
  335  # If origin exists and points elsewhere:
  336  git remote remove origin
  337  gh repo create react-app-k8s --public --source=. --remote=origin --push
  338  git submodule add https://github.com/divyamohan1993/react-k8s-lnt
  339  nano Dockerfile
  340  docker builddocker build -t reactapp .
  341  docker build -t reactapp .
  342  docker run -d -p 3000:3000 reactapp
  343  docker login
  344  docker tag reactapp divyamohan1993/reactapp:01
  345  docker push divyamohan1993/reactapp:01
  346  minikude status
  347  minikube status
  348  minikube start
  349  kubectl run react-pod divyamohan1993/reactapp:01
  350  kubectl run react-pod --image=divyamohan1993/reactapp:01
  351  kubectl run react-pod --image=divyamohan1993/reactapp:01 --port=3000
  352  kubectl delete react-pod
  353  kubectl delete reactapp
  354  kubectl get pods
  355  kubectl expose pod react-pods --type=NodePosrt --port=3000
  356  kubectl expose pod react-pods --type=NodePort --port=3000
  357  kubectl expose pod react-pod --type=NodePort --port=3000
  358  minikube service react-pods --url
  359  minikube service react-pod --url
  360  kubectl create deployment reactapp --image=divyamohan1993/reactapp:01
  361  kubectl get deployment
  362  kubectl get pods
  363  kubectl expose deployment reactapp --type=NodePort --port=3000
  364  minikube service reactapp --url
  365  ls
  366  cd reactapp/
  367  ls 
  368  cd nameofreactapp/
  369  ls
  370  nano src/App.js
  371  ls
  372  cd ..
  373  ls
  374  cd nameofreactapp/
  375  docker build -t divyamohan1993/reactapp:02
  376  cd ..
  377  docker build -t divyamohan1993/reactapp:02
  378  cd ..
  379  docker build -t divyamohan1993/reactapp:02
  380  cd reactapp/
  381  ls
  382  cd nameofreactapp/
  383  ls
  384  docker build -t divyamohan1993/reactapp:02 .
  385  cd reactapp/
  386  history
  387  kubrtl get deployment
  388  kubetl get deployment
  389  kubectl get deployment
  390  kubectl set image deployment/reactapp reactapp=divyamohan1993/reactapp:02
  391  cd nameofreactapp/
  392  docker build -t reactapp:02 .
  393  docker push -t divyamohan1993/reactapp:02 .
  394  history
  395  cd reactapp/
  396  cd nameofreactapp/
  397  docker build -t divyamohan1993/reactapp:02 .
  398  docker push -t divyamohan1993/reactapp:02 .
  399  docker push divyamohan1993/reactapp:02 .
  400  docker push divyamohan1993/reactapp:02
  401  kubectl get deployment
  402  history
  403  kubectl set image deployment/reactapp reactapp=divyamohan1993/reactapp:02
  404  kubsctl get deployment 
  405  kubectl get deployment 
  406  minikube start
  407  kubectl get deployment 
  408  kubectl set image deployment/reactapp reactapp=divyamohan1993/reactapp:02
  409  kubectl rollout status deployment/reactapp
  410  kubectl get all
  411  kubectl get pods
  412  history
  413  sudo ss -ltnp | grep ':80' || true
  414  systemctl status jenkins --no-pager
  415  # Ubuntu/Debian package uses /etc/default/jenkins
  416  sudo sed -i 's/^HTTP_PORT=.*/HTTP_PORT=8081/' /etc/default/jenkins
  417  # (Optional) bind to localhost if using reverse proxy:
  418  # echo 'JENKINS_LISTEN_ADDRESS=127.0.0.1' | sudo tee -a /etc/default/jenkins
  419  sudo systemctl daemon-reload
  420  sudo systemctl restart jenkins
  421  sudo ss -ltnp | egrep ':8081|:80' || true
  422  curl -I http://127.0.0.1:8081/login 2>/dev/null | head -1
  423  # Change the listen port in your Jenkins site (e.g., to 8081)
  424  sudo sed -i 's/^\s*listen 80.*/    listen 8081;/' /etc/nginx/sites-available/jenkins
  425  sudo sed -i 's/^\s*listen \[::\]:80.*/    listen [::]:8081;/' /etc/nginx/sites-available/jenkins
  426  sudo nginx -t && sudo systemctl reload nginx
  427  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/sonarcube/run-latest.sh
  428  chmod +x run-latest.sh
  429  sudo ./run-latest.sh 
  430  ls
  431  ls -l
  432  rm autocon*
  433  ls -l
  434  rm run-l*
  435  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/sonarcube/run-latest.sh
  436  chmod 755 run-latest.sh 
  437  ./run-latest.sh 
  438  sudo ./run-latest.sh 
  439  ls -l
  440  cat autoconfig.sh 
  441  sudo ./autoconfig.sh 
  442  # 1) Give Jenkins a path prefix so URLs/assets work behind /jenkins
  443  if grep -q '^JENKINS_ARGS=' /etc/default/jenkins; then   sudo sed -i 's|^JENKINS_ARGS=.*|JENKINS_ARGS="--prefix=/jenkins"|' /etc/default/jenkins; else   echo 'JENKINS_ARGS="--prefix=/jenkins"' | sudo tee -a /etc/default/jenkins >/dev/null; fi
  444  # (Optional) set the advertised URL Jenkins uses in links/emails
  445  VMIP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
  446  if grep -q '^JENKINS_URL=' /etc/default/jenkins; then   sudo sed -i 's|^JENKINS_URL=.*|JENKINS_URL="http://'"$VMIP"'/jenkins/"|' /etc/default/jenkins; else   echo 'JENKINS_URL="http://'"$VMIP"'/jenkins/"' | sudo tee -a /etc/default/jenkins >/dev/null; fi
  447  sudo systemctl restart jenkins
  448  # 2) Replace NGINX site with a combined config: / -> SonarQube, /jenkins -> Jenkins
  449  sudo tee /etc/nginx/sites-available/sonar-jenkins >/dev/null <<'NGINX'
  450  server {
  451      listen 80 default_server;
  452      listen [::]:80 default_server;
  453      server_name _;
  454      # --- SonarQube at /
  455      location / {
  456          proxy_pass         http://127.0.0.1:9000;
  457          proxy_set_header   Host $host;
  458          proxy_set_header   X-Real-IP $remote_addr;
  459          proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
  460          proxy_set_header   X-Forwarded-Proto $scheme;
  461          proxy_http_version 1.1;
  462          proxy_read_timeout 600s;
  463          proxy_connect_timeout 60s;
  464          proxy_send_timeout 60s;
  465      }
  466      # --- Jenkins at /jenkins (Jenkins started with --prefix=/jenkins)
  467      location /jenkins/ {
  468          proxy_pass         http://127.0.0.1:8080/jenkins/;
  469          proxy_set_header   Host $host;
  470          proxy_set_header   X-Real-IP $remote_addr;
  471          proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
  472          proxy_set_header   X-Forwarded-Proto $scheme;
  473          proxy_set_header   X-Forwarded-Prefix /jenkins;
  474          proxy_buffering    off;
  475          proxy_http_version 1.1;
  476          # WebSocket upgrade (console, BlueOcean, etc.)
  477          proxy_set_header   Upgrade $http_upgrade;
  478          proxy_set_header   Connection "upgrade";
  479      }
  480  }
NGINX
  482  # Enable the combined site (replace any earlier 'sonarqube' or 'default')
  483  sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/sonarqube
  484  sudo ln -sf /etc/nginx/sites-available/sonar-jenkins /etc/nginx/sites-enabled/sonar-jenkins
  485  sudo nginx -t && sudo systemctl reload nginx
  486  # 3) Quick sanity checks
  487  echo "External IP: http://$VMIP/"
  488  curl -fsSI "http://127.0.0.1:9000" | head -1 || true
  489  curl -fsSI "http://127.0.0.1:8080/jenkins/login" | head -1 || true
  490  sudo ss -ltnp | egrep ':80|:8080' || true
  491  ./run-latest.sh 
  492  sudo ./run-latest.sh 
  493  nano autoconfig.sh 
  494  rm autoconfig.sh 
  495  nano autoconfig.sh
  496  mkdir sonarcube
  497  cd sonarcube/
  498  nano compose.yml
  499  docker compose up -d
  500  history
  501  sudo grep -E 'sonar.jdbc.(url|username|password)' /opt/sonarqube/conf/sonar.properties | sed 's/^#//'
  502  sudo -u postgres psql
  503  docker ps
  504  docker exec -it sonarqube bash
  505  docker exec -it postgres-db bash
  506  docker exec -it sonarcube-db bash
  507  # Open psql inside the Postgres container
  508  docker exec -it sonarqube-db psql -U postgres
  509  # Open psql inside the Postgres container
  510  docker exec -it sonarqube-db psql -U postgres
  511  docker exec sonarqube printenv | grep -i sonar
  512  # Open psql inside the Postgres container
  513  docker exec -it sonarqube-db psql -U sonar
  514  docker exec -it sonarqube-db psql -U postgre
  515  docker exec -e PGPASSWORD=sonar -it sonarqube-db   psql -U sonar -d sonarqube
  516  # Stop & remove containers (ignore errors if not present)
  517  docker rm -f sonarqube sonarqube-db 2>/dev/null || true
  518  # Remove any dedicated network if you used one
  519  docker network rm sonar-net 2>/dev/null || true
  520  # Remove images (theyâ€™ll be re-pulled)
  521  docker rmi -f sonarqube:community postgres:15 2>/dev/null || true
  522  # Remove ONLY sonar-related volumes (safer than wiping all)
  523  for v in $(docker volume ls -q | grep -E 'sonar|sonarqube|postgres'); do   docker volume rm "$v" 2>/dev/null || true; done
  524  docker compose down -v
  525  ls
  526  cd sonarcube/
  527  ls
  528  docker compose up -d
  529  docker run  --cpus=1 --memory=2g   -e DELEGATE_NAME=docker-delegate   -e NEXT_GEN="true"   -e DELEGATE_TYPE="DOCKER"   -e ACCOUNT_ID=KhA01sm-SnOLQge-Kbtcdg   -e DELEGATE_TOKEN=ZDYxN2UyMTlkNDVjYjcyZDY2NWE0Yzk4ZjI3MzhlNWE=   -e DELEGATE_TAGS=""   -e MANAGER_HOST_AND_PORT=https://app.harness.io us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.08.86600
  530  docker run  --cpus=0.1 --memory=100m   -v /var/run/docker.sock:/var/run/docker.sock   -e ACCOUNT_ID=KhA01sm-SnOLQge-Kbtcdg   -e MANAGER_HOST_AND_PORT=https://app.harness.io   -e UPGRADER_WORKLOAD_NAME=docker-delegate   -e UPGRADER_TOKEN=ZDYxN2UyMTlkNDVjYjcyZDY2NWE0Yzk4ZjI3MzhlNWE=   -e CONTAINER_STOP_TIMEOUT=3600   -e SCHEDULE="0 */1 * * *" harness/upgrader:latest
  531  docker run  --cpus=0.1 --memory=100m   -v /var/run/docker.sock:/var/run/docker.sock   -e ACCOUNT_ID=KhA01sm-SnOLQge-Kbtcdg   -e MANAGER_HOST_AND_PORT=https://app.harness.io   -e UPGRADER_WORKLOAD_NAME=docker-delegate   -e UPGRADER_TOKEN=ZDYxN2UyMTlkNDVjYjcyZDY2NWE0Yzk4ZjI3MzhlNWE=   -e CONTAINER_STOP_TIMEOUT=3600   -e SCHEDULE="0 */1 * * *" harness/upgrader:latest
  532  docker ps
  533  docker run  --cpus=1 --memory=2g   -e DELEGATE_NAME=docker-delegate   -e NEXT_GEN="true"   -e DELEGATE_TYPE="DOCKER"   -e ACCOUNT_ID=KhA01sm-SnOLQge-Kbtcdg   -e DELEGATE_TOKEN=ZDYxN2UyMTlkNDVjYjcyZDY2NWE0Yzk4ZjI3MzhlNWE=   -e DELEGATE_TAGS=""   -e MANAGER_HOST_AND_PORT=https://app.harness.io us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.08.86600
  534  history
  535  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/capstone/run-latest.sh
  536  ls 
  537  rm run-*
  538  ls
  539  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/capstone/run-latest.sh
  540  chmod run-latest.sh 
  541  chmod  +x run-latest.sh 
  542  sudo ./run-latest.sh 
  543  docker --version
  544  sudo run-latest.sh 
  545  ls
  546  sudo run-latest.sh 
  547  sudo ./run-latest.sh 
  548  docker ps
  549  docker delete triapp-db-1
  550  docker rm triapp-db-1
  551  docker rm triapp-db-1 -f
  552  docker rm triapp-backend-1 -f
  553  docker ps
  554  sudo ./run-latest.sh
  555  docker ps
  556  sudo ./run-latest.sh
  557  sudo ./run-latest.sh 
  558  sudo apt-get install -y apt-transport-https software-properties-common wget
  559  sudo mkdir -p /etc/apt/keyrings/
  560  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  561  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
  562  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com beta main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
  563  # Updates the list of available packages
  564  sudo apt-get update
  565  # Installs the latest OSS release:
  566  sudo apt-get install grafana
  567  sudo systemctl daemon-reload
  568  sudo systemctl start grafana-server
  569  sudo systemctl status grafana-server
  570  docker network create monitor
  571  docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  572  docker rm -f prometheus 2>/dev/null || true
  573  # If this exists as a directory, remove it so we can create the real file
  574  [ -d "$HOME/prometheus/prometheus.yml" ] && rm -rf "$HOME/prometheus/prometheus.yml"
  575  sudo docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  576  docker rm -f prometheus 2>/dev/null || true
  577  # If this exists as a directory, remove it so we can create the real file
  578  [ -d "$HOME/prometheus/prometheus.yml" ] && rm -rf "$HOME/prometheus/prometheus.yml"
  579  sudo docker rm -f prometheus 2>/dev/null || true
  580  # If this exists as a directory, remove it so we can create the real file
  581  [ -d "$HOME/prometheus/prometheus.yml" ] && rm -rf "$HOME/prometheus/prometheus.yml"
  582  su
  583  docker rm -f prometheus 2>/dev/null || true
  584  # If this exists as a directory, remove it so we can create the real file
  585  [ -d "$HOME/prometheus/prometheus.yml" ] && rm -rf "$HOME/prometheus/prometheus.yml"
  586  sudo docker rm -f Prometheus 2>/dev/null || true 
  587  [ -d "$HOME/prometheus/prometheus.yml" ] && sudo rm -rf "$HOMPrometheusus/prometheus.yml" 
  588  mkdir -p "$HOME/prometheus"
  589  cat > "$HOME/prometheus/prometheus.yml" <<'YAML'
  590  global:
  591    scrape_interval: 15s
  592  scrape_configs:
  593    - job_name: 'prometheus'
  594      static_configs:
  595        - targets: ['localhost:9090']
YAML
  597  # sanity check: should show a regular file (-rw-...), not a directory
  598  ls -l "$HOME/prometheus/prometheus.yml"
  599  docker run -d --name prometheus --restart unless-stopped   --network monitor -p 9090:9090   --mount type=bind,source="$HOME/prometheus/prometheus.yml",target=/etc/prometheus/prometheus.yml   prom/prometheus
  600  cd ~
  601  mkdir prometheus
  602  ls
  603  ls prometheus/
  604  cat prometheus/prometheus.yml/
  605  mkdir -p "$HOME/prometheus-data"
  606  # Prometheus often runs as nobody (65534); give it write access:
  607  sudo chown -R 65534:65534 "$HOME/prometheus-data"
  608  docker rm -f prometheus
  609  docker run -d --name prometheus --restart unless-stopped   --network monitor -p 9090:9090   --mount type=bind,source="$HOME/prometheus/prometheus.yml",target=/etc/prometheus/prometheus.yml,readonly   --mount type=bind,source="$HOME/prometheus-data",target=/prometheus   prom/prometheus
  610  cd prometheus
  611  ls
  612  cat prometheus.yml
  613  nano prometheus.yml
  614  rm prometheus.yml/
  615  rmdir prometheus.yml
  616  sudo rmdir prometheus.yml
  617  nano prometheus.yml
  618  sudo nano prometheus.yml
  619  sudo docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  620  docker ps
  621  docker rm prometheus -f
  622  sudo docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  623  docker ps
  624  sudo docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  625  docker rm prometheus -f
  626  sudo docker run -d --name prometheus --network monitor -p 9090:9090 -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
  627  docker run -d --name node_exporter --network monitor prom/node-exporter
  628  history
  629  sudo systemctl start grafana-server
  630  # Node Exporter (host metrics)
  631  docker run -d --name node-exporter --restart unless-stopped   --network monitor   --pid="host"   -p 9100:9100   -v /proc:/host/proc:ro   -v /sys:/host/sys:ro   -v /:/rootfs:ro   quay.io/prometheus/node-exporter:latest   --path.rootfs=/rootfs
  632  # cAdvisor (container metrics) - optional
  633  docker run -d --name cadvisor --restart unless-stopped   --network monitor   -p 8080:8080   -v /:/rootfs:ro   -v /var/run:/var/run:ro   -v /sys:/sys:ro   -v /var/lib/docker/:/var/lib/docker:ro   gcr.io/cadvisor/cadvisor:latest
  634  nano prometheus/prometheus.yml 
  635  sudo nano prometheus/prometheus.yml 
  636  docker rm -f cadvisor 2>/dev/null || true
  637  docker run -d --name cadvisor --restart unless-stopped   --network monitor   -v /:/rootfs:ro   -v /var/run:/var/run:ro   -v /sys:/sys:ro   -v /var/lib/docker/:/var/lib/docker:ro   gcr.io/cadvisor/cadvisor:latest
  638  docker network inspect monitor | jq '.[0].Containers|keys'
  639  docker logs prometheus --tail=200
  640  docker logs cadvisor --tail=200
  641  docker restart prometheus
  642  sudo nano prometheus/prometheus.yml 
  643  docker restart prometheus
  644  sudo nano prometheus/prometheus.yml 
  645  docker restart prometheus
  646  docker ps
  647  sudo nano prometheus/prometheus.yml 
  648  docker restart prometheus
  649  sudo apt-get install curl gpg apt-transport-https --yes
  650  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  651  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  652  sudo apt-get update
  653  sudo apt-get install helm
  654  history
  655  helm version
  656  helm list
  657  services:
  658  volumes:
  659  helm repo add bitnami https://charts.bitnami.com/bitnami
  660  helm search repo bitnami
  661  helm repo update
  662  helm search repo bitnami
  663  helm repo list
  664  helm search repo nginx
  665  helm install mynginx bitnami/nginx
  666  minikube start
  667  helm install mynginx bitnami/nginx
  668  kubectl get all
  669  helm show values bitnami/nginx
  670  helm show values bitnami/nginx > myvalues.yml
  671  do changes
  672  helm upgrade mynginx bitnami/nginx -f myvalues.yml
  673  helm list
  674  helm get manifest mynginx
  675  helm uninstall mynginx
  676  helm create mychart
  677  ls
  678  ls mychart/
  679  cd mychart/
  680  ls
  681  ls -lh
  682  ls -lf
  683  cat values.yml
  684  cat values.yaml 
  685  cat Chart.yaml
  686  nano Chart.yaml
  687  cd mychart/
  688  nano Chart.yaml 
  689  nano values.yaml 
  690  cd templates/
  691  ls
  692  nano deployment.yaml 
  693  mv deployment.yaml  deployment.yaml.bak
  694  nano deployment.yaml
  695  mv deployment.yaml.bak deployment.yaml
  696  nano service.yaml
  697  cd ..
  698  helm install mynginx ./mychart
  699  history
  700  kubectl get pods
  701  kubectl get svc
  702  helm uninstall chatname
  703  helm uninstall chartname
  704  helm uninstall mychart
  705  help list
  706  helm list
  707  helm uninstall mychart-0.1.0
  708  helm uninstall mynginx
  709  helm list
  710  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  711  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  712  rm argocd-linux-amd64
  713  ls
  714  rm run-latest.sh 
  715  rm autoconfig.sh 
  716  clear
  717  wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/argocd/run-latest.sh
  718  chmod +x run-latest.sh 
  719  sudo ./run-latest.sh 
  720  nano ins.sh
  721  chmod +x ins.sh 
  722  sudo ./ins.sh install
  723  ./ins.sh install
  724  kubectl create namespace demo
  725  history > h.html
```