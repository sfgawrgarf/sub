#!/bin/bash

# 如果没有提供参数，则提示用户输入
if [ "$#" -lt 2 ]; then
    echo "请输入域名或IP:"
    read DOMAIN_OR_IP
    echo "注意确保输入的端口后2位未被使用"
    echo "如输入61000,那么61001和61002都不能被占用"
    echo "请输入端口:"
    read PORT
else
    DOMAIN_OR_IP=$1
    PORT=$2
fi

# 将输入的端口转为整数，方便后续计算
PORT=$((PORT))
PORT_PLUS1=$((PORT + 1))
PORT_PLUS2=$((PORT + 2))

# 优化的 Nginx 配置内容
NGINX_CONFIG=$(cat <<EOF
server {
    listen 61000; #使用的端口
    server_name 127.0.0.1 or you domain name; #你的域名或者直接服务器IP

    # 禁止访问的文件或目录
    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404;
    }

    # PROXY-START/
    client_max_body_size 5000M;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Sec-WebSocket-Extensions \$http_sec_websocket_extensions;
    proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
    proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
    
    # 🔧 新增：防止Cloudflare拦截的关键头部
    proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36";
    proxy_set_header Accept "application/json, text/plain, */*";
    proxy_set_header Accept-Language "zh-CN,zh;q=0.9,en;q=0.8";
    proxy_set_header Accept-Encoding "gzip, deflate, br";
    proxy_set_header DNT "1";
    proxy_set_header Connection "keep-alive";
    
    proxy_cache off;
    proxy_redirect off;
    proxy_buffering off;

    location / {
        proxy_pass http://cfhd.xmsl.org;
        proxy_set_header Host cfhd.xmsl.org;
        
        # 🔧 优化CORS头部
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization,Content-Type,Accept,Origin,User-Agent,DNT,Cache-Control,X-Mx-ReqToken,Keep-Alive,X-Requested-With,If-Modified-Since' always;
        
        # 处理OPTIONS预检请求
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
        
        proxy_set_header REMOTE-HOST \$remote_addr;
        proxy_ssl_verify off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        
        # 🔧 禁用缓存，避免Cloudflare缓存API响应
        proxy_no_cache 1;
        proxy_cache_bypass 1;
        add_header X-Cache \$upstream_cache_status;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
    
    # 🔧 新增：健康检查端点
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
)

# 配置 1：替换 listen 和 server_name
CONFIG1=$(echo "$NGINX_CONFIG" | sed -e "s/listen [0-9]*;/listen $PORT;/" -e "s/server_name .*;/server_name $DOMAIN_OR_IP;/")

# 配置 2：替换 listen、hd.xmsl.org 和 server_name
CONFIG2=$(echo "$NGINX_CONFIG" | sed -e "s/listen [0-9]*;/listen $PORT_PLUS1;/" \
                                     -e "s/cfhd\.xmsl\.org/cfloacl.emby.moe/g" \
                                     -e "s/server_name .*;/server_name $DOMAIN_OR_IP;/")

# 配置 3：替换 listen、hd.xmsl.org 和 server_name
CONFIG3=$(echo "$NGINX_CONFIG" | sed -e "s/listen [0-9]*;/listen $PORT_PLUS2;/" \
                                     -e "s/cfhd\.xmsl\.org/cf.xmsl.org/g" \
                                     -e "s/server_name .*;/server_name $DOMAIN_OR_IP;/")

# 检查目录是否存在，不存在则创建
CONFIG_DIR="/etc/nginx/conf.d"
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Directory $CONFIG_DIR does not exist. Creating it..."
    mkdir -p "$CONFIG_DIR"
fi

# 写入文件，直接覆盖
echo "$CONFIG1" > "$CONFIG_DIR/gyemby.conf"
echo "$CONFIG2" > "$CONFIG_DIR/gyemby1.conf"
echo "$CONFIG3" > "$CONFIG_DIR/gyemby2.conf"

echo "✅ 优化后的配置已写入:"
echo "  $CONFIG_DIR/gyemby.conf"
echo "  $CONFIG_DIR/gyemby1.conf"
echo "  $CONFIG_DIR/gyemby2.conf"
echo ""
echo "🔧 重要：重启Nginx服务生效"
echo "sudo systemctl restart nginx"
echo "sudo nginx -t  # 先测试配置语法"
