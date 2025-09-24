```bash
    1  quit
    2  exit
    3  sudo apt update
    4  sudo apt upgradeall
    5  sudo apt upgrade all
    6  sudo apt upgrade 
    7  exit
    8  sudo apt update
    9  sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc   https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
   10  echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]"   https://pkg.jenkins.io/debian-stable binary/ | sudo tee   /etc/apt/sources.list.d/jenkins.list > /dev/null
   11  sudo apt-get update
   12  sudo apt-get install jenkins
   13  sudo systemctl start jenkins
   14  sudo systemctl status jenkins
   15  nano /var/lib/jenkins/secrets/initialAdminPassword
   16  sudo nano /var/lib/jenkins/secrets/initialAdminPassword
   17  sudo nano /var/lib/jenkins/secrets/initialAdminPassword
   18  sudo nano /var/lib/jenkins/secrets/initialAdminPassword
   19  EXIT
   20  EXIT
   21  EXIT
   22  EXIT
   23  quit
   24  exit
   25  exit
   26  exit
   27  sudo apt list
   28  clear
   29  exit
   30  wsl --list --running
   31  exit
   32  ubuntu config --default-user dmj
   33  exit
   34  # inside Ubuntu
   35  sed -i 's/^# force_color_prompt=yes/force_color_prompt=yes/' ~/.bashrc
   36  echo 'export TERM=xterm-256color' >> ~/.bashrc
   37  source ~/.bashrc
   38  history
   39  exit
   40  whoami
   41  sed -i 's/^# force_color_prompt=yes/force_color_prompt=yes/' ~/.bashrc
   42  echo 'export TERM=xterm-256color' >> ~/.bashrc
   43  source ~/.bashrc
   44  exit
   45  # Ensure .profile always loads .bashrc
   46  grep -qxF 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' ~/.profile ||   echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.profile
   47  # Set TERM in both places (idempotent)
   48  grep -qxF 'export TERM=xterm-256color' ~/.bashrc   || echo 'export TERM=xterm-256color' >> ~/.bashrc
   49  grep -qxF 'export TERM=xterm-256color' ~/.profile  || echo 'export TERM=xterm-256color' >> ~/.profile
   50  echo 'export TERM=xterm-256color' | sudo tee /etc/profile.d/00-term.sh >/dev/null
   51  sed -i 's/^# force_color_prompt=yes/force_color_prompt=yes/' ~/.bashrc
   52  source ~/.profile
   53  exit
   54  source ~/.profile
   55  exit
   56  # 1) .profile always sources .bashrc
   57  grep -qxF 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' ~/.profile ||   echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.profile
   58  # 2) Put TERM in both files (idempotent)
   59  grep -qxF 'export TERM=xterm-256color' ~/.bashrc  || echo 'export TERM=xterm-256color' >> ~/.bashrc
   60  grep -qxF 'export TERM=xterm-256color' ~/.profile || echo 'export TERM=xterm-256color' >> ~/.profile
   61  # 3) System-wide safety net (login shells)
   62  echo 'export TERM=xterm-256color' | sudo tee /etc/profile.d/00-term.sh >/dev/null
   63  source ~/.profile
   64  echo $TERM   # should print xterm-256color
   65  @"
   66  [wsl2]
   67  memory=4GB
   68  processors=4
   69  swap=0
   70  localhostForwarding=true
   71  "@ | Set-Content -Encoding utf8NoBOM $env:USERPROFILE\.wslconfig
   72  wsl --shutdown
   73  wsl
   74  exit
   75  exit
   76  # 1) .profile → .bashrc (idempotent; you already did this)
   77  grep -qxF 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' ~/.profile ||   echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.profile
   78  # 2) Also cover login shells that prefer .bash_profile
   79  grep -qxF '[ -f ~/.bashrc ] && . ~/.bashrc' ~/.bash_profile ||   echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile
   80  # 3) Put TERM in both files (safe if already present)
   81  grep -qxF 'export TERM=xterm-256color' ~/.bashrc  || echo 'export TERM=xterm-256color' >> ~/.bashrc
   82  grep -qxF 'export TERM=xterm-256color' ~/.profile || echo 'export TERM=xterm-256color' >> ~/.profile
   83  # 4) System-wide safety net (already OK if present)
   84  echo 'export TERM=xterm-256color' | sudo tee /etc/profile.d/00-term.sh >/dev/null
   85  # 1) .profile → .bashrc (idempotent; you already did this)
   86  grep -qxF 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' ~/.profile ||   echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.profile
   87  # 2) Also cover login shells that prefer .bash_profile
   88  grep -qxF '[ -f ~/.bashrc ] && . ~/.bashrc' ~/.bash_profile ||   echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile
   89  # 3) Put TERM in both files (safe if already present)
   90  grep -qxF 'export TERM=xterm-256color' ~/.bashrc  || echo 'export TERM=xterm-256color' >> ~/.bashrc
   91  grep -qxF 'export TERM=xterm-256color' ~/.profile || echo 'export TERM=xterm-256color' >> ~/.profile
   92  # 4) System-wide safety net (already OK if present)
   93  echo 'export TERM=xterm-256color' | sudo tee /etc/profile.d/00-term.sh >/dev/null
   94  echo $TERM   # should be xterm-256color every time
   95  source ~/.profile
   96  sudo apt update
   97  exit
   98  wget https://dmj.one/edu/su/course/csu1287/misc/project
   99  ls
  100  ./project 
  101  docker pull jenkins/jenkins:jdk21
  102  docker run -p 9090:8080 jenkins/jenkins:jdk21
  103  docker pull jenkins/jenkins:jdk21
  104  exit
  105  sudo apt-get update
  106  # apt-transport-https may be a dummy package; if so, you can skip that package
  107  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  108  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  109  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
  110  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  111  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
  112  sudo apt-get update
  113  sudo apt-get install -y kubectl
  114  curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
  115  sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
  116  minikube start
  117  kubectl cluster-info
  118  sudo usermod -aG docker $USER
  119  docker --version
  120  kubectl create deployment nginx --image=nginx
  121  kubectl get deployment
  122  kubectl get pods
  123  exit
  124  sudo apt update
  125  sudo apt install ntpdate
  126  sudo ntpdate -q pool.ntp.org
  127  sudo ntpdate -q time.google.com
  128  sudo ntpdate -q time.nist.gov
  129  exit
  130  git version
  131  git config help
  132  git config 
  133  git config get-all
  134  git config --get-all
  135  git config -l
  136  ls
  137  cd ~
  138  ls
  139  history > h.txt
```