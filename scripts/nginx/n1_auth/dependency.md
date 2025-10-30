dependency needed: (already satisfied in this docker container)

1. auth.pass 

in /dependency/

htpasswd -bc auth.pass hello 123456  (username:hello, passwd:123456)

this auth.pass is used in nginx.conf auth_basic_user_file field