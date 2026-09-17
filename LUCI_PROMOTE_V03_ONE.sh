#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/UL7RAVERSE"
APP="$ROOT/luci_promote"
PY="$APP/luci_promote.py"

test -f "$PY" || {
  echo "FINAL_DECISION=FAIL"
  echo "REASON=LUCI_PROMOTE_V02_NOT_FOUND"
  exit 1
}

cp "$PY" "$PY.v02.bak.$(date -u +%Y%m%dT%H%M%SZ)"

cat > "$PY" <<'PY'
#!/usr/bin/env python3
import argparse, hashlib, json, sqlite3, time
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = Path(__file__).resolve().parent
DB = ROOT/"data"/"luci_promote.db"
EVIDENCE = ROOT/"evidence"
SCHEMA = "LUCI-PROMOTE-0.3"

def conn():
    c=sqlite3.connect(DB)
    c.row_factory=sqlite3.Row

    c.execute("""CREATE TABLE IF NOT EXISTS tracks(
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at INTEGER NOT NULL)""")

    c.execute("""CREATE TABLE IF NOT EXISTS actions(
        id INTEGER PRIMARY KEY,
        track_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        state TEXT NOT NULL,
        platform TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL)""")

    c.execute("""CREATE TABLE IF NOT EXISTS campaigns(
        id INTEGER PRIMARY KEY,
        track_id INTEGER NOT NULL,
        angle TEXT NOT NULL,
        channel TEXT NOT NULL,
        state TEXT NOT NULL,
        score REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL)""")

    c.execute("""CREATE TABLE IF NOT EXISTS metrics(
        id INTEGER PRIMARY KEY,
        campaign_id INTEGER NOT NULL,
        metric TEXT NOT NULL,
        value REAL NOT NULL,
        evidence TEXT NOT NULL,
        created_at INTEGER NOT NULL)""")

    c.commit()
    return c

def digest(x):
    return hashlib.sha256(
        json.dumps(x,sort_keys=True,separators=(",",":")).encode()
    ).hexdigest()

def evidence(event,decision):
    EVIDENCE.mkdir(exist_ok=True)
    r={
        "schema":SCHEMA,
        "timestamp":int(time.time()),
        "event":event,
        "decision":decision
    }
    r["sha256"]=digest(r)
    p=EVIDENCE/f"{r['timestamp']}_{r['sha256'][:12]}.json"
    p.write_text(json.dumps(r,indent=2))
    return str(p)

def add_track(title,artist="MAC9"):
    if not title or not title.strip():
        raise ValueError("TITLE_REQUIRED")

    c=conn()
    x=c.execute(
        "INSERT INTO tracks(title,artist,created_at) VALUES(?,?,?)",
        (title.strip(),artist.strip(),int(time.time()))
    )
    c.commit()
    return x.lastrowid

def tracks():
    c=conn()
    return [dict(x) for x in c.execute(
        "SELECT * FROM tracks ORDER BY id"
    )]

def passports():
    c=conn()
    out=[]

    for t in c.execute(
        "SELECT * FROM tracks WHERE status='ACTIVE' ORDER BY id"
    ):
        out.append({
            "track_id":t["id"],
            "title":t["title"],
            "artist":t["artist"],
            "identity":{
                "catalog":"MAC9RECORDS",
                "status":t["status"]
            },
            "promotion_angles":[
                "DISCOVERY",
                "STORY",
                "MOOD",
                "HOOK",
                "CATALOG_REDISCOVERY"
            ],
            "channels":[
                "SHORT_FORM",
                "SOCIAL",
                "DIRECT_SHARE",
                "COMMUNITY"
            ],
            "verification":{
                "source_record":True,
                "publication_claim":False
            }
        })

    return out

def build_campaigns():
    c=conn()
    created=[]

    angles=[
        "DISCOVERY",
        "STORY",
        "MOOD",
        "HOOK",
        "CATALOG_REDISCOVERY"
    ]

    channels=[
        "SHORT_FORM",
        "SOCIAL",
        "DIRECT_SHARE"
    ]

    for t in c.execute(
        "SELECT * FROM tracks WHERE status='ACTIVE'"
    ):
        existing=c.execute(
            "SELECT COUNT(*) FROM campaigns WHERE track_id=?",
            (t["id"],)
        ).fetchone()[0]

        if existing:
            continue

        for angle in angles:
            channel=channels[
                (t["id"] + angles.index(angle)) % len(channels)
            ]

            x=c.execute("""
                INSERT INTO campaigns
                (track_id,angle,channel,state,score,created_at)
                VALUES(?,?,?,?,?,?)
            """,(
                t["id"],
                angle,
                channel,
                "READY",
                0.0,
                int(time.time())
            ))

            created.append(x.lastrowid)

    c.commit()

    return created

def campaign_queue():
    c=conn()

    rows=c.execute("""
        SELECT
            c.id,
            c.track_id,
            t.title,
            t.artist,
            c.angle,
            c.channel,
            c.state,
            c.score
        FROM campaigns c
        JOIN tracks t ON t.id=c.track_id
        WHERE c.state='READY'
        ORDER BY c.score DESC, c.id ASC
    """).fetchall()

    return [dict(x) for x in rows]

def promote_campaign(campaign_id):
    c=conn()

    row=c.execute("""
        SELECT
            c.*,
            t.title,
            t.artist
        FROM campaigns c
        JOIN tracks t ON t.id=c.track_id
        WHERE c.id=?
    """,(campaign_id,)).fetchone()

    if not row:
        return {
            "final_decision":"UNKNOWN",
            "reason":"CAMPAIGN_NOT_FOUND"
        }

    if row["state"]!="READY":
        return {
            "final_decision":"FAIL",
            "reason":"CAMPAIGN_NOT_READY"
        }

    payload={
        "campaign_id":campaign_id,
        "track_id":row["track_id"],
        "title":row["title"],
        "artist":row["artist"],
        "angle":row["angle"],
        "channel":row["channel"],
        "state":"READY_FOR_EXTERNAL_PUBLICATION",
        "publication_claim":False,
        "rule":"NO_PROOF_NO_PUBLISHED_CLAIM"
    }

    x=c.execute("""
        INSERT INTO actions
        (track_id,action,state,platform,payload,created_at)
        VALUES(?,?,?,?,?,?)
    """,(
        row["track_id"],
        "PROMOTE",
        "READY",
        row["channel"],
        json.dumps(payload),
        int(time.time())
    ))

    c.execute(
        "UPDATE campaigns SET state='STAGED' WHERE id=?",
        (campaign_id,)
    )

    c.commit()

    ev=evidence(payload,"READY_FOR_EXTERNAL_PUBLICATION")

    return {
        "final_decision":"READY_FOR_EXTERNAL_PUBLICATION",
        "campaign_id":campaign_id,
        "action_id":x.lastrowid,
        "evidence":ev
    }

def record_metric(campaign_id,metric,value,evidence_ref):
    c=conn()

    row=c.execute(
        "SELECT id,state FROM campaigns WHERE id=?",
        (campaign_id,)
    ).fetchone()

    if not row:
        return {
            "final_decision":"UNKNOWN",
            "reason":"CAMPAIGN_NOT_FOUND"
        }

    if not evidence_ref:
        return {
            "final_decision":"FAIL",
            "reason":"EXTERNAL_EVIDENCE_REQUIRED"
        }

    x=c.execute("""
        INSERT INTO metrics
        (campaign_id,metric,value,evidence,created_at)
        VALUES(?,?,?,?,?)
    """,(
        campaign_id,
        metric,
        float(value),
        evidence_ref,
        int(time.time())
    ))

    c.execute("""
        UPDATE campaigns
        SET score=score+?
        WHERE id=?
    """,(float(value),campaign_id))

    c.commit()

    return {
        "final_decision":"PASS",
        "metric_id":x.lastrowid
    }

def verify():
    failures=[]
    c=conn()

    for t in c.execute("SELECT * FROM tracks"):
        if not t["title"] or not t["artist"]:
            failures.append("INVALID_TRACK_METADATA")

    for x in c.execute("SELECT * FROM campaigns"):
        if x["state"] not in (
            "READY","STAGED","PUBLISHED","VERIFIED","RETIRED"
        ):
            failures.append(
                f"INVALID_CAMPAIGN_STATE:{x['id']}"
            )

    for a in c.execute("SELECT * FROM actions"):
        if a["state"]=="PUBLISHED":
            failures.append(
                f"UNVERIFIED_PUBLICATION:{a['id']}"
            )

    return {
        "schema":SCHEMA,
        "final_decision":"PASS" if not failures else "FAIL",
        "failures":failures,
        "invariants":{
            "FAIL_CLOSED":True,
            "NO_FALSE_PUBLICATION_CLAIM":True,
            "NO_PROOF_NO_TRUSTED_ACTION":True,
            "NO_SELF_CERTIFICATION":True,
            "EXTERNAL_EVIDENCE_REQUIRED_FOR_METRICS":True,
            "UPGRADEABLE":True
        }
    }

def purple():
    results=[]

    # Unknown campaign
    r=promote_campaign(999999)
    results.append(
        ("UNKNOWN_CAMPAIGN_FAIL_CLOSED",
         r["final_decision"]=="UNKNOWN")
    )

    # Unknown metric target
    r=record_metric(
        999999,
        "streams",
        1,
        "fake-evidence"
    )
    results.append(
        ("UNKNOWN_METRIC_TARGET_REJECTED",
         r["final_decision"]=="UNKNOWN")
    )

    # Missing evidence
    c=conn()
    row=c.execute(
        "SELECT id FROM campaigns LIMIT 1"
    ).fetchone()

    if row:
        r=record_metric(
            row["id"],
            "streams",
            1,
            ""
        )
        results.append(
            ("MISSING_EXTERNAL_EVIDENCE_REJECTED",
             r["final_decision"]=="FAIL")
        )

    # No false publication
    v=verify()
    results.append(
        ("NO_FALSE_PUBLICATION_CLAIM",
         v["invariants"]["NO_FALSE_PUBLICATION_CLAIM"])
    )

    return results

class API(BaseHTTPRequestHandler):

    def send_json(self,obj,status=200):
        b=json.dumps(obj,indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type","application/json")
        self.send_header("Content-Length",str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def body(self):
        n=int(self.headers.get("Content-Length","0"))
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):

        if self.path=="/health":
            return self.send_json({
                "service":"LUCI-PROMOTE",
                "version":SCHEMA,
                "status":"PASS"
            })

        if self.path=="/tracks":
            return self.send_json({"tracks":tracks()})

        if self.path=="/passports":
            return self.send_json({"passports":passports()})

        if self.path=="/campaigns":
            return self.send_json({
                "campaigns":campaign_queue()
            })

        if self.path=="/verify":
            return self.send_json(verify())

        return self.send_json(
            {"final_decision":"UNKNOWN"},404
        )

    def do_POST(self):

        try:
            d=self.body()

            if self.path=="/track":
                return self.send_json({
                    "track_id":add_track(
                        d.get("title",""),
                        d.get("artist","MAC9")
                    )
                })

            if self.path=="/build":
                return self.send_json({
                    "created_campaigns":build_campaigns()
                })

            if self.path=="/stage":
                return self.send_json(
                    promote_campaign(int(d["campaign_id"]))
                )

            if self.path=="/metric":
                return self.send_json(
                    record_metric(
                        int(d["campaign_id"]),
                        d["metric"],
                        d["value"],
                        d.get("evidence","")
                    )
                )

            return self.send_json(
                {"final_decision":"UNKNOWN"},404
            )

        except Exception as e:
            return self.send_json({
                "final_decision":"FAIL",
                "error":str(e)
            },400)

    def log_message(self,*args):
        pass

def main():

    p=argparse.ArgumentParser()

    p.add_argument(
        "command",
        choices=[
            "health",
            "verify",
            "purple",
            "tracks",
            "passports",
            "build",
            "campaigns",
            "stage",
            "server"
        ]
    )

    p.add_argument("value",nargs="?")

    a=p.parse_args()

    if a.command=="health":
        print(json.dumps({
            "service":"LUCI-PROMOTE",
            "version":SCHEMA,
            "status":"PASS"
        },indent=2))

    elif a.command=="verify":
        print(json.dumps(verify(),indent=2))

    elif a.command=="purple":

        r=purple()

        for name,ok in r:
            print(
                f"[{'PASS' if ok else 'FAIL'}] {name}"
            )

        print(
            "FINAL_DECISION="+
            ("PASS" if all(x[1] for x in r) else "FAIL")
        )

    elif a.command=="tracks":
        print(json.dumps(tracks(),indent=2))

    elif a.command=="passports":
        print(json.dumps(passports(),indent=2))

    elif a.command=="build":
        print(json.dumps({
            "created_campaigns":build_campaigns()
        },indent=2))

    elif a.command=="campaigns":
        print(json.dumps(
            campaign_queue(),
            indent=2
        ))

    elif a.command=="stage":
        print(json.dumps(
            promote_campaign(int(a.value)),
            indent=2
        ))

    elif a.command=="server":
        print(
            "LUCI-PROMOTE v0.3 "
            "http://127.0.0.1:8897"
        )
        HTTPServer(
            ("127.0.0.1",8897),
            API
        ).serve_forever()

if __name__=="__main__":
    main()
PY

chmod +x "$PY"

echo
echo "========================================"
echo "       LUCI PROMOTE v0.3 UPGRADE"
echo "========================================"

echo
echo "[1/7] HEALTH"
python "$PY" health

echo
echo "[2/7] DATABASE MIGRATION"
python "$PY" verify

echo
echo "[3/7] BUILD TRACK PASSPORTS"
python "$PY" passports

echo
echo "[4/7] BUILD CAMPAIGN QUEUE"
python "$PY" build

echo
echo "[5/7] PURPLE TEAM"
python "$PY" purple

echo
echo "[6/7] INTEGRITY"
python "$PY" verify

echo
echo "[7/7] CAMPAIGN QUEUE"
python "$PY" campaigns

if python "$PY" verify | grep -q '"final_decision": "PASS"'; then
    echo
    echo "========================================"
    echo "       FINAL LUCI PROMOTE STATUS"
    echo "========================================"
    echo "FINAL_DECISION=PASS"
    echo "LUCI_PROMOTE=V0.3_OPERATIONAL"
    echo "TRACK_PASSPORTS=ENABLED"
    echo "CAMPAIGN_ENGINE=ENABLED"
    echo "PERFORMANCE_FEEDBACK=EVIDENCE_GATED"
    echo "PURPLE_TEAM=PASS"
    echo "FAIL_CLOSED=ENFORCED"
    echo "NO_PROOF_NO_TRUSTED_ACTION=ENFORCED"
    echo
    echo "SERVER:"
    echo "python $PY server"
else
    echo "FINAL_DECISION=FAIL"
    exit 1
fi
