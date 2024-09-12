FROM redis:latest

# remove the docker-entrypoint.sh ENTRYPOINT created by redis
ENTRYPOINT []

COPY redis.conf /usr/local/etc/redis/redis.conf

EXPOSE 6379

ENV REDIS_PASSWORD=mysecretpassword
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
