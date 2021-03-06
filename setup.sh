#!/bin/bash
set -e
OS="$(uname -s)"
DOT_DIRECTORY="${HOME}/dotfiles"
DOT_TARBALL="https://github.com/kyohah/dotfiles/tarball/master"
REMOTE_URL="https://github.com/kyohah/dotfiles.git"

has() {
  type "$1" > /dev/null 2>&1
}

usage() {
  name=`basename $0`
  cat <<EOF
Usage:
  $name [arguments] [command]

Commands:
  deploy
  initialize

Arguments:
  -f $(tput setaf 1)** warning **$(tput sgr0) Overwrite dotfiles.
  -h Print help (this message)
EOF
  exit 1
}

while getopts :f:h opt; do
  case ${opt} in
    f)
      OVERWRITE=true
      ;;
    h)
      usage
      ;;
  esac
done
shift $((OPTIND - 1))

# If missing, download and extract the dotfiles repository
if [ ! -d ${DOT_DIRECTORY} ]; then
  echo "Downloading dotfiles..."
  mkdir ${DOT_DIRECTORY}

  if has "git"; then
    git clone --recursive "${REMOTE_URL}" "${DOT_DIRECTORY}"
  else
    curl -fsSLo ${HOME}/dotfiles.tar.gz ${DOT_TARBALL}
    tar -zxf ${HOME}/dotfiles.tar.gz --strip-components 1 -C ${DOT_DIRECTORY}
    rm -f ${HOME}/dotfiles.tar.gz
  fi

  echo $(tput setaf 2)Download dotfiles complete!. ✔︎$(tput sgr0)
fi

cd ${DOT_DIRECTORY}
source ./lib/brew
source ./lib/go
source ./lib/apt-get
source ./lib/yarn

link_files() {
  for f in .??*
  do
    # Force remove the vim directory if it's already there
    [ -n "${OVERWRITE}" -a -e ${HOME}/${f} ] && rm -f ${HOME}/${f}
    if [ ! -e ${HOME}/${f} ]; then
      # If you have ignore files, add file/directory name here
      [[ ${f} = ".git" ]] && continue
      [[ ${f} = ".gitignore" ]] && continue
      ln -snfv ${DOT_DIRECTORY}/${f} ${HOME}/${f}
    fi
  done

  echo $(tput setaf 2)Deploy dotfiles complete!. ✔︎$(tput sgr0)
}

initialize() {
  case ${OSTYPE} in
    darwin*)
      run_brew

      if [ ! -e ~/Library/Fonts/Cica-Regular.ttf ]; then
        wget https://github.com/miiton/Cica/releases/download/v2.1.0/Cica_v2.1.0.zip
        unar Cica_v2.1.0.zip
        cp -f Cica_v2.1.0/Cica*.ttf ${HOME}/Library/Fonts/
        rm -rf Cica_v2.1.0*
      fi
      ;;
    linux-gnu)
      run_apt
      ;;
    *)
      echo $(tput setaf 1)Working only OSX / Ubuntu!!$(tput sgr0)
      exit 1
      ;;
  esac

  [ ${SHELL} != "/bin/zsh"  ] && chsh -s /bin/zsh

  if [ ! -d ${HOME}/.anyenv ]; then
    git clone https://github.com/riywo/anyenv ~/.anyenv
    anyenv install goenv
    anyenv install rbenv
    anyenv install pyenv
    anyenv install phpenv
    anyenv install ndenv
    exec $SHELL -l
  fi

  run_go
  run_yarn

  [ ! -d ${HOME}/.zplug ] && curl -sL zplug.sh/installer | zsh
  [ ! -d ${HOME}/.tmux/plugins/tpm ] && git clone https://github.com/tmux-plugins/tpm ${HOME}/.tmux/plugins/tpm
  ghq get -u flutter/flutter.git
  flutter doctor

  set +e
  if has "pyenv"; then
    [ ! -d $(pyenv root)/plugins/pyenv-virtualenv ] && git clone https://github.com/yyuu/pyenv-virtualenv $(pyenv root)/plugins/pyenv-virtualenv
    pyenv virtualenv -f ${latest} neovim3
    pyenv activate neovim3
    pip install neovim
  fi
  if has "rbenv"; then
    [ ! -d $(rbenv root)/plugins/rbenv-default-gems ] && git clone -q https://github.com/rbenv/rbenv-default-gems.git $(rbenv root)/plugins/rbenv-default-gems
    [ ! -e $(rbenv root)/default-gems ] && cp ${DOT_DIRECTORY}/default-gems $(rbenv root)/default-gems
  fi
  if [ ! -d $HOME/.cargo ]; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
  fi

  echo "$(tput setaf 2)Initialize complete!. ✔︎$(tput sgr0)"
}

command=$1
[ $# -gt 0 ] && shift

case $command in
  deploy)
    link_files
    ;;
  init*)
    initialize
    ;;
  *)
    usage
    ;;
esac

exit 0
