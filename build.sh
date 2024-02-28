#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 恢复默认颜色

# 第一步：检查系统版本当前目录容量
current_dir=$(pwd)
available_space=$(df -h "$current_dir" | awk 'NR==2 {print $4}')
required_space="30G"
if [ "$available_space" \< "$required_space" ]; then
    echo "${RED}容量不足，请清理后再运行${NC}"
    exit 1
fi

# 第一步：升级系统
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip libpython3-dev qemu-utils \
rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev

# 第二步：检查当前目录是否存在名为open-build的文件夹
echo "${YELLOW}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
echo "${YELLOW}欢迎使用Openwrt懒人编译脚本${NC}"
echo "${YELLOW}Github地址：https://github.com/breeze303/openwrt-build${NC}"
echo "${YELLOW}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
if [ -d "open-build" ]; then
    echo "${YELLOW}----------------${NC}"
    echo "${GREEN}该文件夹已存在${NC}"
    echo "${YELLOW}----------------${NC}"
else
    mkdir "open-build"
    echo "${YELLOW}----------------${NC}"
    echo "${GREEN}已新建文件夹${NC}"
    echo "${YELLOW}----------------${NC}"
fi

# 第三步：检查当前目录是否存在目标文件夹
existing_dirs=""
for dir in openwrt lede immortalwrt ipq60xx-6.1; do
    if [ -d "$dir" ]; then
        existing_dirs="$existing_dirs $dir"
    fi
done

if [ -n "$existing_dirs" ]; then
    echo "${YELLOW}------------------${NC}"
    echo "${YELLOW}已存在的文件夹: $existing_dirs${NC}"
    echo "${YELLOW}------------------${NC}"
    read -p "请输入想要进入的文件夹？(回车则跳过)" choice
    if [ -d "$choice" ]; then
        cd "$choice" || exit 1
        git pull
    fi
fi

# 第四步：下载选项
if [ -z "$choice" ]; then
    echo "${GREEN}********************************${NC}"
    echo "${YELLOW}请选择下载选项:${NC}"
    echo "${YELLOW}1. openwrt${NC}"
    echo "${YELLOW}2. LEDE${NC}"
    echo "${YELLOW}3. immortalwrt${NC}"
    echo "${YELLOW}4. IPQ60XX库${NC}"
    echo "${GREEN}********************************${NC}"
    read -p "请输入选择（1、2、3、4）:" choice

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
        echo "${RED}错误：无效的选择${NC}"
        exit 1
        ;;
    esac

        # 输入分支名称
        read -p "请输入分支名称（回车则使用默认分支）：" branch

        # 下载指定的 Git 仓库
        echo "${YELLOW}----------------${NC}"
        echo "${GREEN}开始下载源码...${NC}"
        echo "${YELLOW}----------------${NC}"
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
fi

    # 第五步：更新 feeds
    REPO_NAME=$(basename "$REPO_URL" .git)
    cd "$REPO_NAME" || exit 1
    if 
        ./scripts/feeds update -a && ./scripts/feeds install -a; then
        echo "${YELLOW}----------------${NC}"
        echo "${GREEN}feeds更新成功${NC}"
        echo "${YELLOW}----------------${NC}"
    else
        echo "${YELLOW}----------------${NC}"
        echo "${RED}feeds更新失败${NC}"
        echo "${YELLOW}----------------${NC}"
        exit 1
    fi

# 第六步：选择配置文件
echo "${YELLOW}请选择:${NC}"
echo "${YELLOW}1. 导入本地配置文件${NC}"
echo "${YELLOW}2. 导入其他路径配置文件${NC}"
echo "${YELLOW}3. 新建配置文件${NC}"
echo "${YELLOW}按回车键跳过${NC}"
read -p "输入选项编号: " option

case $option in
    1)
        make defconfig
        ;;

    2)
        #导入已有配置文件并执行 make defconfig
        read -p "请输入已有配置文件的路径：" config_path
        cp "$config_path" .config
        make defconfig

        if [ $? -ne 0 ]; then
            echo -e "${RED}导入配置文件并执行 make defconfig 失败${NC}"
            exit 1
        fi
        ;;
    3)
        make menuconfig
        ;;

    *)
        echo "${YELLOW}跳过配置文件步骤${NC}"
        ;;
esac

# 第七步：下载
echo "${YELLOW}----------------${NC}"
echo "${GREEN}下载DL库中...${NC}"
echo "${YELLOW}----------------${NC}"
for i in {1..3}; do
    if make download -j8; then
        echo "${GREEN}下载成功${NC}"
        break
    else
        echo "${RED}第 $i 次下载失败${NC}"
        if [ $i -eq 3 ]; then
            echo "${RED}下载失败，请检查网络连接${NC}"
            exit 1
        fi
    fi
done

# 第八步：编译
echo "${YELLOW}----------------${NC}"
echo "${GREEN}开始编译...${NC}"
echo "${YELLOW}----------------${NC}"
if make V=s -j$(nproc); then
    echo "${GREEN}固件编译成功${NC}"
else
    echo "${RED}固件编译失败，请检查错误${NC}"
    exit 1
fi
