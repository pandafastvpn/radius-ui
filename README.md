# NETORA-Radius

FreeRADIUS带面板的一键安装，改造基于https://github.com/desienkz-slp/radius-ui
将英文改为简体中文，并且删除WireGuard和L2TP的安装，增加ocserv群组支持（添加新用户组--附加属性（高级）--Class（ocserv 用户组）然后选择:=(设置)--填入ocserv的群组名）
## 安装方法


1. 一个干净的debian 12/Ubuntu 22.04/20.04 Linux服务器（全新安装）。
2. 运行自动安装命令如下 `root`:
   ```bash
   apt update && apt install git sudo -y
   git clone https://github.com/pandafastvpn/radius-ui.git
   cd radius-ui
   sudo bash install.sh
   ```
4. 等待流程完成。所有服务（Nginx、MariaDB、Node.js、FreeRADIUS）都将自动完成安装。

## 默认登录信息


安装完成后，在浏览器中访问服务器的IP地址（或者域名）。



-'http://192.168.1.10' （替换自己的ip或域名）
- **默认用户名**: `superadmin`
- **默认密码**: `admin123`

强烈建议在首次成功登录后立即更改密码，以保障服务器安全



## 其他的参考原作者

