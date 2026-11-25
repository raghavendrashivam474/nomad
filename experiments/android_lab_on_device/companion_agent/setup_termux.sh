#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Nomad Android Lab: Termux Companion Setup ==="

# 1. Update packages
pkg update -y

# 2. Install essential build toolchain
pkg install -y openjdk-17 gradle dart git wget curl tar

# 3. Create Android SDK and workspace directories
mkdir -p "$HOME/android-sdk/platforms"
mkdir -p "$HOME/android-sdk/build-tools"
mkdir -p "$HOME/nomad_builds"

# 4. Set Environment Variables in .bashrc if not present
if ! grep -q "ANDROID_HOME" "$HOME/.bashrc" 2>/dev/null; then
    echo 'export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-17-openjdk"' >> "$HOME/.bashrc"
    echo 'export ANDROID_HOME="$HOME/android-sdk"' >> "$HOME/.bashrc"
    echo 'export PATH="$PATH:$ANDROID_HOME/platform-tools"' >> "$HOME/.bashrc"
fi

export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-17-openjdk"
export ANDROID_HOME="$HOME/android-sdk"

echo ""
echo "=== Verification ==="
java -version
gradle --version
dart --version

echo ""
echo "Termux environment ready for Nomad Companion Agent!"
