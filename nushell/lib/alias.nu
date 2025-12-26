alias quit = exit
alias la = ls -a
alias ll = ls -la
alias l = ls
alias .. = cd ..
alias ... = cd ../..
alias rmrf = rm -rf

alias g = git
alias gst = git status

alias t = if (which tofu | is-not-empty) { tofu } else { terraform }
alias tf = if (which tofu | is-not-empty) { tofu } else { terraform }

alias tm = tmux
alias tmn = tmux new -s
alias tmls = tmux ls
alias tma = tmux attach -t
alias tmk = tmux kill-session -t
alias tmmv = tmux rename-session -t

alias d = docker
alias de = docker exec -it
alias dm = docker-machine
alias ds = docker service
alias dsl = docker service logs
alias dsps = docker service ps
alias dsls = docker service ls
alias dn = docker network
alias dsw = docker swarm

alias pi = pip install -r requirements.txt
alias pe = pyenv
alias per = pyenv rehash
alias pev = pyenv version
alias pvs = pyenv versions

alias k = kubectl
alias kg = kubectl get
alias kgp = kubectl get pod
alias kgs = kubectl get service
alias kgss = kubectl get statefulset
alias kd = kubectl describe
alias kdp = kubectl describe pod
alias kds = kubectl describe service
alias kdss = kubectl describe statefulset
alias ke = kubectl exec -ti
alias kc = kubectl create -f
alias kr = kubectl replace -f
alias kt = kubectl logs -f

alias lower = str downcase
alias upper = str upcase

# List aliases starting with a prefix
def list_alias_starts_with [prefix: string] {
    help aliases
        | where name =~ $"^($prefix)"
        | select name usage
        | sort-by name
}

# Alias helpers
def tmh [] { list_alias_starts_with "tm" }
def dh [] { list_alias_starts_with "d" }
def ph [] { list_alias_starts_with "p" }
def kh [] { list_alias_starts_with "k" }
