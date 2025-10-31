# Dojo intro

This repository contains a (very) simple [Dojo](https://book.dojoengine.org/) game.
The goal is to showcase how Dojo works and ease the developement for on-chain applications and games.

The game is built in two parts:

- `contracts`: The Dojo contracts deployed on Starknet.
- `client`: The client application that interacts with the contracts (and read data using Torii).

## Setup environment

To work with Dojo, install the toolchain using `asdf`:

```bash
curl -L https://install.dojoengine.org | bash
```

## Deploy contracts

A simple "spawn and move" game letting you generate a character and move them around a board.

To set up your local blockchain environment, change directory to `contracts` and run:

```bash
# Run a script to start up katana, build and deploy the world, and start up torii
scarb run dev
```

## Run client

A simple vite project (no React), configured to use `https` (necessary for the [Cartridge controller](https://docs.cartridge.gg/controller/overview)).

Head to the `client` directory and run:

```bash
# Install dependencies and run the client locally
pnpm install && pnpm run dev
```

You should be all set to play the game!
Navigate to your browser and start clicking away.

Currently, the best browser to test locally with Controller is Google Chrome.
