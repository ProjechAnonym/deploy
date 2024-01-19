#!/bin/bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "nameserver 192.168.234.4" > /etc/resolv.conf


mkdir -p /opt/singbox
mkdir -p /opt/sing2cat/config
mkdir -p /opt/sing2cat/config/static
mkdir -p /opt/sing2cat/temp
mkdir -p /opt/mosdns
mkdir -p /opt/script

chmod +w /opt/singbox
chmod +w /opt/script
chmod +w /opt/sing2cat/temp
chmod +w /opt/sing2cat
mv DeployPackage/config.json /opt/singbox
mv DeployPackage/sing-box /opt/singbox
mv DeployPackage/mosdns /opt/mosdns
mv DeployPackage/sing2cat /opt/sing2cat

chmod +x /opt/mosdns/mosdns
chmod +x /opt/sing2cat/sing2cat
chmod +x /opt/singbox/sing-box

cat > /opt/script/singbox.sh <<EOF
#!/bin/bash
cp /opt/singbox/config.json /opt/sing2cat/temp/config.json.bak
/opt/sing2cat/sing2cat
config=true
if [ \$config == true ]; then
	if [ -e /opt/sing2cat/temp/config.json ]; then
		if [ -s /opt/sing2cat/temp/config.json ]; then
			echo "下载成功"
		else
			echo "下载失败"
			config=false
		fi
	else
		echo "不存在"
		config=false
	fi
fi


if [ \$config == true ]; then
	systemctl stop sing-box.service
	rm -rf /opt/singbox/config.json
	cp /opt/sing2cat/temp/config.json /opt/singbox/config.json
	systemctl start sing-box.service
else
	echo "不更新"
fi

sleep 3
if systemctl status sing-box.service |grep -q "running"; then
	echo "更新完成"
	rm -rf /opt/sing2cat/temp/config.json.bak
else
	echo "似乎哪里暴毙了,开始恢复"
	rm -rf /opt/singbox/config.json
	cp /opt/sing2cat/temp/config.json.bak /opt/singbox/config.json
	rm -rf /opt/sing2cat/temp/config.json.bak
	systemctl start sing-box.service
fi

EOF

chmod +x /opt/script/singbox.sh

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

cat > /opt/sing2cat/config/config.json <<EOF
{
  "url": [
    "https://link.onesy.link/link/xQ3S0L9btfgTpr"
  ],
  "rule_set": [
  ]
}
EOF

cat > /opt/sing2cat/config/static/template.json <<EOF
{
  "country": [
    "加拿大",
    "阿根廷",
    "美国",
    "香港",
    "台湾",
    "新加坡",
    "韩国",
    "日本",
    "未知地区"
  ],
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "external",
        "address": "https://8.8.8.8/dns-query",
        "address_strategy": "ipv4_only",
        "strategy": "prefer_ipv4",
        "detour": "select"
      },
      {
        "tag": "nodes_dns",
        "address": "https://1.1.1.1/dns-query",
        "address_strategy": "ipv4_only",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "internal",
        "address": "https://223.5.5.5/dns-query",
        "address_strategy": "ipv4_only",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      { "tag": "dns_block", "address": "rcode://refused" }
    ],
    "rules": [
      { "outbound": "any", "server": "nodes_dns" },
      { "rule_set": "geosite-cn", "server": "internal", "rewrite_ttl": 43200 },
      {
        "rule_set": "geosite-cn",
        "invert": true,
        "server": "external",
        "rewrite_ttl": 43200
      }
    ],
    "strategy": "prefer_ipv4",
    "final": "external",
    "disable_cache": false,
    "disable_expire": false,
    "independent_cache": false,
    "reverse_mapping": false
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.19.0.1/30",
      "mtu": 1500,
      "auto_route": true,
      "strict_route": false,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": false
    }
  ],
  "outbounds": {
    "ss": {
      "type": "shadowsocks",
      "tag": "",
      "server": "",
      "server_port": "",
      "method": "",
      "password": ""
    },
    "vmess": {
      "type": "vmess",
      "tag": "",
      "server": "",
      "server_port": "",
      "uuid": "",
      "security": "auto",
      "transport": {
        "type": "ws",
        "path": "/",
        "headers": {},
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    "trojan": {
      "type": "trojan",
      "tag": "",
      "server": "",
      "server_port": "",
      "password": "",
      "tls": {
        "enabled": true,
        "disable_sni": false,
        "server_name": "",
        "insecure": true
      }
    },
    "select": {
      "type": "selector",
      "tag": "select",
      "outbounds": [],
      "default": "auto",
      "interrupt_exist_connections": false
    },
    "auto": {
      "type": "urltest",
      "tag": "auto",
      "outbounds": [],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "5m",
      "tolerance": 100,
      "interrupt_exist_connections": false
    },
    "direct": { "type": "direct", "tag": "direct" },
    "dns_out": { "type": "dns", "tag": "dns-out" },
    "block": { "type": "block", "tag": "block" }
  },
  "route": {
    "rule_set": [
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "select"
      },
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
        "download_detour": "select"
      }
    ],
    "rules": [
      { "protocol": "dns", "outbound": "dns-out" },
      { "ip_is_private": true, "outbound": "direct" },
      { "protocol": ["quic"], "outbound": "block" },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          { "rule_set": "geosite-cn", "invert": true },
          { "rule_set": "geoip-cn", "invert": true }
        ],
        "outbound": "select"
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [{ "rule_set": "geosite-cn" }, { "rule_set": "geoip-cn" }],
        "outbound": "direct"
      }
    ],
    "final": "select",
    "auto_detect_interface": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "0.0.0.0:9090",
      "external_ui": "ui",
      "external_ui_download_url": "https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "select",
      "secret": "123456"
    },
    "cache_file": { "enabled": true, "path": "/opt/singbox/cache.db" }
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

echo "30 4 * * * /opt/script/singbox.sh" >> /tmp/conf && crontab /tmp/conf && rm -f /tmp/conf

systemctl daemon-reload
systemctl enable sing-box.service
systemctl enable mosdns.service

reboot

