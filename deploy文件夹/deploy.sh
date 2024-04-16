#!/bin/bash

# 使用GitHub API获取最新的发行版信息（里边有最新的版本号标识）
response=$(curl -s https://api.github.com/repos/IrineSistiana/mosdns/releases/latest)

# 提取下载链接 （tag_name属性即为版本号属性 cut命令获取版本号属性的值 awk命令把版本号中的v字符删除）
version=$(echo "$response" | grep 'tag_name' | cut -d'"' -f4 | awk '{print substr($0, 2, length($0) - 1)'})

# 拼接下载连接
download_url=https://github.com/IrineSistiana/mosdns/releases/download/v$version/mosdns-linux-amd64.zip
echo “下载mosdns完成”
# 使用curl下载最新发行版（-L意思是支持重定向，很多下载都是重定向下载  -o是自定义名字）
curl -L -o mosdns-linux-amd64.zip $download_url

# 使用GitHub API获取最新的发行版信息（里边有最新的版本号标识）
response=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest)

# 提取下载链接 （tag_name属性即为版本号属性 cut命令获取版本号属性的值 awk命令把版本号中的v字符删除）
version=$(echo "$response" | grep 'tag_name' | cut -d'"' -f4 | awk '{print substr($0, 2, length($0) - 1)'})

# 拼接下载连接
download_url=https://github.com/SagerNet/sing-box/releases/download/v$version/sing-box-$version-linux-amd64.tar.gz
curl -L -o sing-box-$version-linux-amd64.tar.gz $download_url


unzip mosdns*.zip

mkdir /opt/mosdns
mkdir /opt/singbox

mkdir -p /opt/sing2cat/log
mkdir -p /opt/sing2cat/temp
mkdir -p /opt/sing2cat/static

mv Sing2CatWeb/sing2cat_web /opt/sing2cat
mv Sing2CatWeb/build /opt/sing2cat
mv Sing2CatWeb/config /opt/sing2cat
mv Sing2CatWeb/static/index.html /opt/sing2cat/static

chmod -R 777 /opt/mosdns
chmod -R 777 /opt/sing2cat
chmod -R 777 /opt/singbox

mv mosdns /opt/mosdns

chmod +x /opt/mosdns/mosdns
chmod +x /opt/sing2cat/sing2cat_web


cat > /opt/mosdns/config.yaml <<EOF
log:
  level: info
  file: "/opt/mosdns/mosdns.log"

api:
  http: "0.0.0.0:9091"

include: []

plugins:
  - tag: hosts
    type: hosts
    args:
      entries:
        - "woshiwo.com 192.168.234.4"
        - "shibuyiyangdeyanhuo.com 192.168.234.2"    

  - tag: forward_dns
    type: forward
    args:
      concurrent: 1
      upstreams:
        - addr: 1.1.1.1
          bootstrap: 119.29.29.29
          enable_pipeline: false
          max_conns: 2
          insecure_skip_verify: false
          idle_timeout: 30
          enable_http3: false

  - tag: dns_sequence
    type: sequence
    args:
      - exec: prefer_ipv4
      - exec: \$forward_dns

  - tag: dns_query
    type: sequence
    args:
      - exec: \$dns_sequence

  - tag: fallback
    type: fallback
    args:
      primary: dns_query
      secondary: dns_query
      threshold: 500
      always_standby: true

  - tag: main_sequence
    type: sequence
    args:
      - exec: \$hosts
      - matches:
        - has_resp
        exec: accept
      - exec: \$fallback

  - tag: udp_server
    type: udp_server
    args:
      entry: main_sequence
      listen: "0.0.0.0:53"

  - tag: tcp_server
    type: tcp_server
    args:
      entry: main_sequence
      listen: "0.0.0.0:53"

EOF

cat > /opt/singbox/config.json <<EOF
{
  "dns": {
    "disable_cache": false,
    "disable_expire": false,
    "final": "internal",
    "independent_cache": false,
    "reverse_mapping": false,
    "rules": [],
    "servers": [
      {
        "address": "https://223.5.5.5/dns-query",
        "address_strategy": "ipv4_only",
        "detour": "direct",
        "strategy": "prefer_ipv4",
        "tag": "internal"
      },
      {
        "address": "rcode://refused",
        "tag": "dns_block"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "/opt/singbox/cache.db"
    }
  },
  "inbounds": [
    {
      "auto_route": true,
      "inet4_address": "172.19.0.1/30",
      "mtu": 1500,
      "sniff": true,
      "sniff_override_destination": false,
      "stack": "system",
      "strict_route": false,
      "tag": "tun-in",
      "type": "tun"
    }
  ],
  "log": {
    "level": "info",
    "timestamp": true
  },
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "dns-out",
      "type": "dns"
    },
    {
      "tag": "block",
      "type": "block"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "direct",
    "rule_set": [],
    "rules": [
      {
        "outbound": "dns-out",
        "protocol": "dns"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "outbound": "block",
        "protocol": ["quic"]
      }
    ]
  }
}

EOF

cat > /etc/systemd/system/mosdns.service <<EOF
[Unit]
Description=A DNS forwarder
ConditionFileIsExecutable=/opt/mosdns/mosdns

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/mosdns/mosdns start  -d /opt/mosdns -c /opt/mosdns/config.yaml

Restart=always

RestartSec=120
EnvironmentFile=-/etc/sysconfig/mosdns

[Install]
WantedBy=multi-user.target
EOF


tar -zxvf sing-box-*.tar.gz

mv sing-box-*/sing-box /opt/singbox
chmod +x /opt/singbox/sing-box
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/opt/singbox/sing-box -C /opt/singbox run
ExecReload=/bin/kill -HUP $MAINPID
Restart=Always
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF


cat > /etc/systemd/system/sing2cat.service <<EOF
[Unit]
Description=Sing2CatWeb Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/sing2cat/sing2cat_web
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "nameserver 192.168.233.155" > /etc/resolv.conf