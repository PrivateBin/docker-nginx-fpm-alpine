server {
    listen 80;
    server_name ~^www.(?<domain>.+)$;

    include /etc/nginx/server.d/*.conf;
    return {{REDIRECT_CODE}} {{REDIRECT_PROTO}}://$domain$request_uri;
}
