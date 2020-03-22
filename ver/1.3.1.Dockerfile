FROM registry.gitlab.b-data.ch/julia/ver:1.3.1

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://gitlab.b-data.ch/jupyterlab/julia/docker-stack" \
      maintainer="Olivier Benz <olivier.benz@b-data.ch>"

ARG NB_USER
ARG NB_UID
ARG NB_GID
ARG JUPYTERHUB_VERSION
ARG JUPYTERLAB_VERSION
ARG CODE_SERVER_RELEASE
ARG CODE_WORKDIR
ARG PANDOC_VERSION

ENV NB_USER=${NB_USER:-jovyan} \
    NB_UID=${NB_UID:-1000} \
    NB_GID=${NB_GID:-100} \
    JUPYTERHUB_VERSION=${JUPYTERHUB_VERSION:-1.0.0} \
    JUPYTERLAB_VERSION=${JUPYTERLAB_VERSION:-1.2.6} \
    CODE_SERVER_RELEASE=${CODE_SERVER_RELEASE:-3.0.0} \
    CODE_BUILTIN_EXTENSIONS_DIR=/opt/code-server/extensions \
    PANDOC_VERSION=${PANDOC_VERSION:-2.9}

USER root

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    #curl \
    file \
    fontconfig \
    git \
    gnupg \
    jq \
    less \
    #libclang-dev \
    #lsb-release \
    man-db \
    #multiarch-support \
    nano \
    procps \
    psmisc \
    python3-venv \
    python3-virtualenv \
    ssh \
    sudo \
    vim \
    wget \
    zsh \
    ## Current ZeroMQ library for Julia ZMQ
    #libzmq3-dev \
  ## Clean up
  && rm -rf /var/lib/apt/lists/* \
  ## Install font MesloLGS NF
  && mkdir -p /usr/share/fonts/truetype/meslo \
  && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Regular.ttf \
  && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Bold.ttf \
  && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Italic.ttf \
  && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Bold\ Italic.ttf \
  && fc-cache -fv \
  ## Install pandoc
  && curl -sLO https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb \
  && dpkg -i pandoc-${PANDOC_VERSION}-1-amd64.deb \
  && rm pandoc-${PANDOC_VERSION}-1-amd64.deb \
  ## configure git not to request password each time
  && git config --system credential.helper "cache --timeout=3600" \
  ## Add user
  && useradd -m -s /bin/bash -N -u ${NB_UID} ${NB_USER}

## Install code-server
RUN mkdir -p ${CODE_BUILTIN_EXTENSIONS_DIR} \
  && cd /opt/code-server \
  && curl -sL https://github.com/cdr/code-server/releases/download/${CODE_SERVER_RELEASE}/code-server-${CODE_SERVER_RELEASE}-linux-x86_64.tar.gz | tar zxf - --strip-components=1 \
  && curl -sL https://upload.wikimedia.org/wikipedia/commons/9/9a/Visual_Studio_Code_1.35_icon.svg -o vscode.svg \
  && cd /

ENV PATH=/opt/code-server:$PATH

## Install JupyterLab
RUN curl -sLO https://bootstrap.pypa.io/get-pip.py \
  && python3 get-pip.py \
  && rm get-pip.py \
  ## Install Python packages
  && pip3 install \
    jupyterhub==${JUPYTERHUB_VERSION} \
    jupyterlab==${JUPYTERLAB_VERSION} \
    nbdime==1.1.0 \
    nbgrader==0.5.4 \
    notebook==6.0.3 \
  ## Install Node.js
  && curl -sL https://deb.nodesource.com/setup_12.x | bash \
  && DEPS="libpython-stdlib \
    libpython2-stdlib \
    libpython2.7-minimal \
    libpython2.7-stdlib \
    python \
    python-minimal \
    python2 python2-minimal \
    python2.7 \
    python2.7-minimal" \
  && apt-get install -y --no-install-recommends nodejs $DEPS \
  ## Install JupyterLab extensions
  && pip3 install jupyter-server-proxy jupyterlab-git \
  && jupyter serverextension enable --py jupyter_server_proxy --sys-prefix \
  && jupyter serverextension enable --py nbgrader --sys-prefix \
  && jupyter nbextension install --py nbgrader --sys-prefix --overwrite \
  && jupyter nbextension enable --py nbgrader --sys-prefix \
  && jupyter labextension install @jupyterlab/server-proxy --no-build \
  && jupyter labextension install @jupyterlab/git --no-build \
  && jupyter lab build \
  && echo '{\n  "@jupyterlab/apputils-extension:themes": {\n    "theme": "JupyterLab Dark"\n  }\n}' > /usr/local/share/jupyter/lab/settings/overrides.json \
  ## Install code-server extensions
  && cd /tmp \
  && curl -sL https://marketplace.visualstudio.com/_apis/public/gallery/publishers/alefragnani/vsextensions/project-manager/10.9.1/vspackage -o alefragnani.project-manager-10.9.1.vsix.gz \
  && gunzip alefragnani.project-manager-10.9.1.vsix.gz \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension alefragnani.project-manager-10.9.1.vsix \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension christian-kohler.path-intellisense \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension eamodio.gitlens \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension piotrpalarz.vscode-gitignore-generator \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension redhat.vscode-yaml \
  && code-server --extensions-dir ${CODE_BUILTIN_EXTENSIONS_DIR} --install-extension grapecity.gc-excelviewer \
  && cd / \
  ## Clean up (Node.js)
  && rm -rf /tmp/* \
  && apt-get remove --purge -y nodejs $DEPS \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/* \
    /root/.cache \
    /root/.config \
    /root/.local \
    /root/.npm \
    /usr/local/share/.cache

## Install the Julia kernel for JupyterLab
RUN export JULIA_DEPOT_PATH=${JULIA_PATH}/local/share/julia \
  && julia -e "using Pkg; pkg\"add IJulia Revise\"; pkg\"precompile\"" \
  && chmod -R ugo+r ${JULIA_DEPOT_PATH} \
  && unset JULIA_DEPOT_PATH \
  && mv $HOME/.local/share/jupyter/kernels/julia* /usr/local/share/jupyter/kernels/ \
  && rm -rf $HOME/.local

## Install Tini
RUN curl -sL https://github.com/krallin/tini/releases/download/v0.18.0/tini -o /usr/local/bin/tini \
  && chmod +x /usr/local/bin/tini

## Switch back to ${NB_USER} to avoid accidental container runs as root
USER ${NB_USER}

ENV HOME=/home/${NB_USER} \
    CODE_WORKDIR=${CODE_WORKDIR:-/home/${NB_USER}/projects} \
    SHELL=/usr/bin/zsh \
    TERM=xterm-256color

WORKDIR ${HOME}

RUN mkdir -p .local/share/code-server/User \
  && echo '{\n    "editor.tabSize": 2,\n    "telemetry.enableTelemetry": false,\n    "gitlens.advanced.telemetry.enabled": false,\n    "julia.enableCrashReporter": false,\n    "julia.enableTelemetry": false,\n    "julia.format.indent": 2\n}' > .local/share/code-server/User/settings.json \
  && cp .local/share/code-server/User/settings.json /var/tmp \
  && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended \
  && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git .oh-my-zsh/custom/themes/powerlevel10k \
  #&& sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' .zshrc \
  && echo "\n# set PATH so it includes user's private bin if it exists\nif [ -d "\$HOME/bin" ] ; then\n    PATH="\$HOME/bin:\$PATH"\nfi" | tee -a .bashrc .zshrc \
  && echo "\n# set PATH so it includes user's private bin if it exists\nif [ -d "\$HOME/.local/bin" ] ; then\n    PATH="\$HOME/.local/bin:\$PATH"\nfi" | tee -a .bashrc .zshrc \
  && echo "\n# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh." >> .zshrc \
  && echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> .zshrc

## Copy local files as late as possible to avoid cache busting
COPY *.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/
COPY startup.jl ${JULIA_PATH}/etc/julia/startup.jl
COPY vsix/* /var/tmp/
COPY --chown=$NB_UID:$NB_GID .p10k.zsh.sample .

EXPOSE 8888

## Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["init-notebook.sh"]
