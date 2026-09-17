import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]))
import luci_promote as l

def test_health():
    assert l.SCHEMA.startswith("LUCI-PROMOTE")

def test_track_creation(tmp_path, monkeypatch):
    monkeypatch.setattr(l,"DB",tmp_path/"x.db")
    monkeypatch.setattr(l,"EVIDENCE",tmp_path/"e")
    i=l.add_track("Test Track")
    assert i > 0

def test_fail_closed_unknown_track(tmp_path, monkeypatch):
    monkeypatch.setattr(l,"DB",tmp_path/"x.db")
    monkeypatch.setattr(l,"EVIDENCE",tmp_path/"e")
    assert l.promote(999)["final_decision"]=="UNKNOWN"

def test_no_false_publication(tmp_path, monkeypatch):
    monkeypatch.setattr(l,"DB",tmp_path/"x.db")
    monkeypatch.setattr(l,"EVIDENCE",tmp_path/"e")
    i=l.add_track("Proof Track")
    r=l.promote(i)
    assert r["final_decision"]=="READY_FOR_PROMOTION"
    assert l.verify()["final_decision"]=="PASS"
