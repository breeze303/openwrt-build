#!/bin/bash

# 设置颜色变量
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 第一步：检查系统版本、当前目录容量以及环境依赖是否正确
echo "${YELLOW}检查系统版本和当前目录容量...${NC}"
uname -a
df -h .

# 检查环境依赖并安装
echo "${YELLOW}检查环境依赖...${NC}"
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip libpython3-dev qemu-utils \
rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev

# 检查环境依赖是否安装成功
if [ $? -ne 0 ]; then
    echo -e "${RED}环境依赖错误，请自行修复${NC}"
    exit 1
fi

# 第二步：提供四个选项，选项名称用黄色，下载地址用绿色
echo "${GREEN}---------------------------${NC}"
echo "${YELLOW}请选择要下载的 Git 仓库：${NC}"
echo "${GREEN}1. openwrt${NC}"
echo "${GREEN}2. LEDE${NC}"
echo "${GREEN}3. immortalwrt${NC}"
echo "${GREEN}4. IPQ60XX库${NC}"
echo "${GREEN}---------------------------${NC}"
read -p "请输入选择（1、2、3、4）：" choice
# 根据选择设置对应的下载地址
case $choice in
    1)
        REPO_URL="https://github.com/openwrt/openwrt.git"
        ;;
    2)
        REPO_URL="https://github.com/coolsnowwolf/lede.git"
        ;;
    3)
        REPO_URL="https://github.com/immortalwrt/immortalwrt.git"
        ;;
    4)
        REPO_URL="https://github.com/breeze303/ipq60xx-6.1.git"
        ;;
    *)
        echo -e "${RED}错误：无效的选择${NC}"
        exit 1
        ;;
esac

# 输入分支名称
read -p "请输入分支名称（回车则用默认分支）：" branch

# 下载指定的 Git 仓库
echo "开始下载 Git 仓库..."
if [ -n "$branch" ]; then
    git clone -b "$branch" "$REPO_URL"
else
    git clone "$REPO_URL"
fi

if [ $? -ne 0 ]; then
    echo "${RED}下载失败${NC}"
    exit 1
fi
echo "${GREEN}下载成功${NC}"

# 进入下载的目录
REPO_NAME=$(basename "$REPO_URL" .git)
cd "$REPO_NAME" || exit 1

# 第四步：执行 ./scripts/feeds update -a && ./scripts/feeds install -a
echo "开始更新和安装 feeds..."
./scripts/feeds update -a && ./scripts/feeds install -a
if [ $? -ne 0 ]; then
    echo -e "${RED}更新和安装 feeds 失败${NC}"
    exit 1
fi
echo -e "${GREEN}更新和安装 feeds 成功${NC}"

# 第五步：给两个选项选择
echo "${GREEN}---------------------------${NC}"
echo "${YELLOW}请选择："
echo "${GREEN}1. 导入已有配置文件"
echo "${GREEN}2. 新建配置文件"
echo "${GREEN}---------------------------${NC}"
read -p "请输入选择（1 或 2）：" choice

case $choice in
    1)
        # 选项一：导入已有配置文件并执行 make defconfig
        read -p "请输入已有配置文件的路径：" config_path
        cp "$config_path" .config
        make defconfig

        if [ $? -ne 0 ]; then
            echo -e "${RED}导入配置文件并执行 make defconfig 失败${NC}"
            exit 1
        fi
        ;;
    2)
        # 选项二：新建配置文件并执行 make menuconfig
        make menuconfig

        if [ $? -ne 0 ]; then
            echo -e "${RED}新建配置文件并执行 make menuconfig 失败${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}错误：无效的选择${NC}"
        exit 1
        ;;
esac

# 第六步：执行 make download -j8 命令并输出结果
attempt=1
max_attempts=3

while [ $attempt -le $max_attempts ]; do
    echo "第 $attempt 次尝试下载..."
    make download -j8
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}下载成功${NC}"
        break
    fi
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}下载失败，已重试 $max_attempts 次${NC}"
    exit 1
fi

# 第七步：执行 make V=s -j$(nproc)
echo "开始编译固件..."
make V=s -j$(nproc)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}固件编译成功${NC}"
else
    echo -
