#!/bin/bash
# Liga autenticacao Basic no inventario do GLPI. Uso: SENHA=... bash 30-glpi-auth-inventario.sh <login>
LOGIN=${1:-elux}
ENC=$(docker exec -i -e SENHA="$SENHA" -u www-data glpi php <<'PHP'
<?php
$key = file_get_contents('/var/glpi/config/glpicrypt.key');
$nonce = random_bytes(SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_NPUBBYTES);
$enc = sodium_crypto_aead_xchacha20poly1305_ietf_encrypt(getenv('SENHA'), $nonce, $nonce, $key);
echo base64_encode($nonce . $enc);
PHP
)
[ -n "$ENC" ] || { echo "falhou ao cifrar"; exit 1; }
c() { docker exec -u www-data glpi php bin/console -n config:set --context=inventory "$@"; }
c basic_auth_login "$LOGIN"; c basic_auth_password "$ENC"; c auth_required basic_auth
