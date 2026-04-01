# docker stop nginx-proxy
# docker rm nginx-proxy
docker logs -f nginx-proxy

docker run -d \
  --name nginx-proxy \
  --restart unless-stopped \
  --network teleport-net \
  -v /path/to/your/nginx/nginx.conf:/etc/nginx/nginx.conf \
  -v /path/to/your/ssl_certs:/etc/ssl \
  -v /path/to/your/nginx-html:/usr/share/nginx/html \
  -v /path/to/your/nginx-logs:/var/log/nginx \
  -p 443:443 \
  -p 80:80 \
  nginx:latest