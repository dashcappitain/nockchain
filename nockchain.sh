#!/bin/bash

set -e

echo -e "\n📦 Updating the system and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

echo -e "\n🦀 Install Rust..."
curl --proto '=https' --tlsv1.2 -sSf [URL] | sh -s -- -y
source "$HOME/.cargo/env"
#rustup default stable

echo -e "\n📁 Check nockchain repository..."
if [ -d "nockchain" ]; then
echo "⚠️ The nockchain directory already exists. Do you want to delete it and clone it again (must select y)? (y/n)"
read -r confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
rm -rf nockchain
git clone https://github.com/zorp-corp/nockchain
else
echo "➡️ Use the existing directory nockchain"
fi
else
git clone https://github.com/zorp-corp/nockchain
fi

cd nockchain

echo -e "\n🔧 开始编译核心组件..."
make install-hoonc
make build
make install-nockchain-wallet
make install-nockchain

echo -e "\n✅ Compilation completed, configure environment variables..."
echo 'export PATH="$PATH:$HOME/nockchain/target/release"' >> ~/.bashrc
echo 'export RUST_LOG=info' >> ~/.bashrc
echo 'export MINIMAL_LOG_FORMAT=true' >> ~/.bashrc
source ~/.bashrc

# === Generate wallet ===
echo -e "\n🔐 Automatically generate wallet mnemonics and master private keys..."
WALLET_CMD="./target/release/nockchain-wallet"
if [ ! -f "$WALLET_CMD" ]; then
echo "❌ Wallet command $WALLET_CMD not found"
exit 1
fi

SEED_OUTPUT=$($WALLET_CMD keygen)
echo "$SEED_OUTPUT"

SEED_PHRASE=$(echo "$SEED_OUTPUT" | grep -iE "seed phrase" | sed 's/.*: //')
echo -e "\n🧠 Mnemonic: $SEED_PHRASE"

echo -e "\n🔑 Derive the master private key from the mnemonic..."
MASTER_PRIVKEY=$($WALLET_CMD gen-master-privkey --seedphrase "$SEED_PHRASE" | grep -i "master private key" | awk '{print $NF}')
echo "Master private key: $MASTER_PRIVKEY"

echo -e "\n📬 Get the master public key..."
MASTER_PUBKEY=$($WALLET_CMD gen-master-pubkey --master-privkey "$MASTER_PRIVKEY" | grep -i "master public key" | awk '{print $NF}')
echo "Master public key: $MASTER_PUBKEY"

echo -e "\n📄 Write Makefile mining public key..."
sed -i '' "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $MASTER_PUBKEY|" Makefile

# === Optional: Initialize choo hoon test ===
read -p \n🌀 Do you want to execute choo initialization test? This step may get stuck in the interface and is not a necessary operation. Enter y to continue:' confirm_choo
if [[ "$confirm_choo" == "y" || "$confirm_choo" == "Y" ]]; then
mkdir -p hoon assets
echo "%trivial" > hoon/trivial.hoon
choo --new --arbitrary hoon/trivial.hoon
fi

# === Startup Guide ===
echo -e "\n🚀 Configuration completed, the startup command is as follows:"

echo -e "\n➡️ Start the leader node:"
echo -e "screen -S leader\nmake run-nockchain-leader"

echo -e "\n➡️ Start the follower node:"
echo -e "screen -S follower\nmake run-nockchain-follower"

echo -e "\n📄 How to view logs:"
echo -e "screen -r leader # View leader logs"
echo -e "screen -r follower # View follower logs"
echo -e "Ctrl+A then press D to exit the screen session"

echo -e "\n🎉 Deployment completed, I wish you a happy mining!"