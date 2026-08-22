# NETORA-Radius

FreeRADIUS带面板一键安装，来自https://github.com/desienkz-slp/radius-ui 修改语言为简体中文语言并且支持OCSERV群组，移除WireGuard & L2TP的安装

## 安装步骤


1. 将该仓库的全部内容下载或克隆到一个干净的debian 12/Ubuntu 22.04/20.04 Linux服务器（全新安装）。.
2.进入该仓库的目录（或文件夹名称）
3. 或者使用运行自动安装命令如下 `root`:
   ```bash
   apt update && apt install git -y
   git clone https://github.com/pandafastvpn/radius-ui.git
   cd radius-ui
   chmod +x install.sh
   ./install.sh
   ```
4. 等待流程完成。所有服务（Nginx、MariaDB、Node.js、FreeRADIUS）都将自动安装。.

## 登录默认信息


安装完成后，在浏览器中访问服务器的IP地址（或者域名）。

'http://192.168.1.10'（替换为自己的公网IP）

默认用户名: superadmin
默认密码: admin123
强烈建议在首次成功登录后立即更改密码，以保障服务器安全

其他的参考原版
