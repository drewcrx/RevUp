# Usa los archivos pre-compilados de Flutter web (build/web/)
# Para re-compilar: flutter build web --release  en la maquina local
FROM nginx:alpine

COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
