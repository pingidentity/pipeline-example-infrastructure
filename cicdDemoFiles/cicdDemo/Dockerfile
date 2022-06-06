FROM python:alpine3.15
 
COPY index.html /var/html/
WORKDIR /var/html
EXPOSE 8080
ENTRYPOINT ["python","-m","http.server","8080"]
