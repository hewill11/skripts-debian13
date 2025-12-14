#!/usr/bin/env bash
set -e

apt update
apt install -y apache2
apt install -y curl

systemctl enable apache2
systemctl restart apache2

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>Экзамен_ФАМИЛИЯ СТУДЕНТА</title>
</head>
<body>
    Я на экзамене по МДК 02.01!
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

curl -s http://localhost | head -n 20
