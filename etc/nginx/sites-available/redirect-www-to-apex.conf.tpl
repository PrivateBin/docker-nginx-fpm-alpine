server {
    listen 80;
    server_name ~^www.(?<domain>.+)$;
    return {{REDIRECT_CODE}} {{REDIRECT_PROTO}}://$domain$request_uri;
}
