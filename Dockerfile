FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y software-properties-common git && \
    add-apt-repository ppa:neovim-ppa/unstable && \
    apt-get update && \
    apt-get install -y neovim luarocks python3-pip pipx && \
    pipx install llm && \
    luarocks install busted && \
    luarocks install luassert

WORKDIR /app

COPY . /app
