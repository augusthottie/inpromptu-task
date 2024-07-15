# Preq

- Download nginx
- Before starting nginx, change conf

```conf
# /usr/local/etc/nginx/nginx.conf

worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;

    keepalive_timeout  65;

    # Default server block (can be overridden by specific server blocks)
    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        # Error pages
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

    # Include configurations from the conf.d directory
    include /etc/nginx/conf.d/*.conf;
    include servers/*;
}
```
- start the nginx

# Run the script

sudo bash ./dockssh.sh create (container-name)

## After

After X minutes(ideally 5) you can reach: http://(container-name).localhost
You can change localhost on nginx config and dockssh to host in your own domain.
