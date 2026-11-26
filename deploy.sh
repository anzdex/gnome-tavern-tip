#!/usr/bin/env bash
# Deploy token/ (Gnome Tavern Tip, TIP) ke Onyx testnet. Jalankan SETELAH faucet terisi.
# Kebutuhan: wallet-seed.txt di folder induk (password keybase dibaca dari sana, tidak di-echo).
# Alur offline (TERBUKTI jalan 26 Nov 2026 — JANGAN pakai gnokey -broadcast,
# klien HTTP Go-nya gagal TLS lewat egress proxy VM ini; dan JANGAN broadcast
# pakai curl: POST curl ke RPC publik ini sampai dengan param tx kosong
# (node menjawab hash kosong 47DEQ... + /std.UnknownRequestError).
# Broadcast HARUS via Python urllib: ../broadcast_tx.py
#   1) gnokey maketx addpkg -broadcast=false > tx-unsigned.json
#   2) gnokey sign -tx-path tx-unsigned.json -account-number 2273 -account-sequence <S> -chainid onyx-1
#      (cek sequence terbaru dulu via ABCI query auth/accounts/<addr>)
#   3) python3 ../encode_tx.py tx-unsigned.json   # amino binary2 -> base64 di /tmp/tx-b64.txt
#   4) python3 ../broadcast_tx.py /tmp/tx-b64.txt
# Gas: addpkg ~11KB butuh ~11,2M gas (token: GasUsed 11232582 di blok 1421114).
# Tetap pakai gas-wanted 20M + gas-fee 30000ugnot sebagai margin.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.gno/bin:$PATH"

PASS=$(grep '^# keybase password: ' ../wallet-seed.txt | cut -d' ' -f4)
ADDR=$(grep '^# address: ' ../wallet-seed.txt | cut -d' ' -f3)
RPC="https://rpc.latest.testnets.gno.land:443"
PKG="gno.land/r/$ADDR/token"
SEQ="${SEQ:-$(python3 -c "
import json,urllib.request,base64
b=json.dumps({'jsonrpc':'2.0','id':1,'method':'abci_query','params':{'path':'auth/accounts/$ADDR'}}).encode()
r=json.load(urllib.request.urlopen(urllib.request.Request('$RPC',data=b,headers={'Content-Type':'application/json'}),timeout=30))
print(json.loads(base64.b64decode(r['result']['response']['ResponseBase']['Data']))['BaseAccount']['sequence'])
")}"

echo "Deploying $PKG to Onyx (chain-id onyx-1), sequence $SEQ..."

printf '%s\n' "$PASS" | gnokey maketx addpkg \
	-pkgpath "$PKG" \
	-pkgdir . \
	-gas-fee 30000ugnot -gas-wanted 20000000 \
	-chainid onyx-1 -remote "$RPC" \
	-broadcast=false -simulate test gnome-tavern --insecure-password-stdin \
	> tx-unsigned.json

printf '%s\n' "$PASS" | gnokey sign \
	-tx-path tx-unsigned.json \
	-account-number 2273 -account-sequence "$SEQ" -chainid onyx-1 \
	gnome-tavern --insecure-password-stdin

python3 ../encode_tx.py tx-unsigned.json
python3 ../broadcast_tx.py /tmp/tx-b64.txt

echo "Verify at: https://latest.testnets.gno.land/r/$ADDR/token"
echo "(gnoweb 404 sampai GPAS meng-enable realm; itu normal di mode inert Onyx)"
